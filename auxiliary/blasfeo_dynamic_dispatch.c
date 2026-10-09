/**************************************************************************************************
*                                                                                                 *
* This file is part of BLASFEO.                                                                   *
*                                                                                                 *
* BLASFEO -- BLAS For Embedded Optimization.                                                      *
* Copyright (C) 2019 by Gianluca Frison.                                                          *
* Developed at IMTEK (University of Freiburg) under the supervision of Moritz Diehl.              *
* All rights reserved.                                                                            *
*                                                                                                 *
* The 2-Clause BSD License                                                                        *
*                                                                                                 *
* Redistribution and use in source and binary forms, with or without                              *
* modification, are permitted provided that the following conditions are met:                     *
*                                                                                                 *
* 1. Redistributions of source code must retain the above copyright notice, this                  *
*    list of conditions and the following disclaimer.                                             *
* 2. Redistributions in binary form must reproduce the above copyright notice,                    *
*    this list of conditions and the following disclaimer in the documentation                    *
*    and/or other materials provided with the distribution.                                       *
*                                                                                                 *
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND                 *
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED                   *
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE                          *
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR                 *
* ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES                  *
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;                    *
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND                     *
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT                      *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS                   *
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.                                    *
*                                                                                                 *
**************************************************************************************************/

/*
 * Load-time target selection of a dynamic (TARGET=DYNAMIC) build.
 *
 * Every API function is a stub jumping through blasfeo_dynamic_table
 * (generated, see cmake/BlasfeoDynamicGen.cmake). The table statically points
 * to the last (most conservative) target; the constructor below copies in the
 * implementations of the best target for the CPU, sets the matching panel
 * sizes used by BLASFEO_DMATEL & co, and makes the table read-only.
 *
 * The best target is, in order:
 * - the one named by the environment variable BLASFEO_TARGET (e.g.
 *   X64_INTEL_HASWELL, or just HASWELL), provided the CPU supports it;
 * - the one matching the cores of the CPU, if they can be identified (ARM);
 * - the first one, in order of preference, the CPU supports.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#if defined(_WIN32)
#include <windows.h>
#else
#include <unistd.h>
#include <sys/mman.h>
#endif
#if defined(__x86_64__) || defined(__i386__)
#include <cpuid.h>
#elif defined(__linux__)
#include <sys/auxv.h>
#endif

#if defined(_WIN32)
#define HIDDEN
#else
#define HIDDEN __attribute__((visibility("hidden")))
#endif

#define BLASFEO_DYNAMIC_BUILD
#include "blasfeo_dynamic.h"

HIDDEN void blasfeo_dynamic_abort(const char *name, int arch);

#include "blasfeo_dynamic_table.inc"

static int dynamic_selected = BLASFEO_DYNAMIC_NARCH-1;

// consistent with the static content of blasfeo_dynamic_table
int blasfeo_d_ps = BLASFEO_DYNAMIC_DEFAULT_D_PS;
int blasfeo_s_ps = BLASFEO_DYNAMIC_DEFAULT_S_PS;



const char *blasfeo_dynamic_target(void)
	{
	return dynamic_targets[dynamic_selected];
	}



HIDDEN void blasfeo_dynamic_abort(const char *name, int arch)
	{
	fprintf(stderr, "BLASFEO: %s is not available for target %s\n", name, dynamic_targets[arch]);
	abort();
	}



#if defined(__x86_64__) || defined(__i386__)

static void dynamic_cpu_init(void)
	{
	__builtin_cpu_init();
	}



// CPU can run the target
static int dynamic_supported(const char *target)
	{
	if(!strcmp(target, "X64_INTEL_SKYLAKE_X"))
		return __builtin_cpu_supports("avx512f") && __builtin_cpu_supports("avx512vl") && __builtin_cpu_supports("avx2") && __builtin_cpu_supports("fma");
	if(!strcmp(target, "X64_INTEL_HASWELL"))
		return __builtin_cpu_supports("avx2") && __builtin_cpu_supports("fma");
	if(!strcmp(target, "X64_AMD_BULLDOZER"))
		return __builtin_cpu_supports("avx") && __builtin_cpu_supports("fma");
	if(!strcmp(target, "X64_INTEL_SANDY_BRIDGE"))
		return __builtin_cpu_supports("avx");
	if(!strcmp(target, "X64_INTEL_CORE"))
		return __builtin_cpu_supports("sse3");
	if(!strcmp(target, "GENERIC"))
		return 1;
	return 0;
	}



// target is expected to be faster than the following ones, when supported
static int dynamic_preferred(const char *target)
	{
	if(!strcmp(target, "X64_INTEL_SKYLAKE_X") && __builtin_cpu_is("amd"))
		{
		// AMD before Zen5 (family 0x1A) splits 512-bit FMAs in two halves
		unsigned int eax, ebx, ecx, edx, family;
		if(!__get_cpuid(1, &eax, &ebx, &ecx, &edx))
			return 0;
		family = (eax>>8) & 0xf;
		if(family==0xf)
			family += (eax>>20) & 0xff;
		return family>=0x1a;
		}
	return 1;
	}



// the features of the CPU tell which targets it can run, not which is best
static const char *dynamic_detected(void)
	{
	return NULL;
	}

#elif defined(__aarch64__) && defined(__APPLE__)

static void dynamic_cpu_init(void)
	{
	}



// all ARMv8A targets use the same ISA
static int dynamic_supported(const char *target)
	{
	return 1;
	}



static int dynamic_preferred(const char *target)
	{
	return 1;
	}



static const char *dynamic_detected(void)
	{
	return "ARMV8A_APPLE_M1";
	}

#elif defined(__aarch64__) && defined(__linux__)

#ifndef HWCAP_CPUID
#define HWCAP_CPUID (1 << 11)
#endif

static void dynamic_cpu_init(void)
	{
	}



// all ARMv8A targets use the same ISA
static int dynamic_supported(const char *target)
	{
	return 1;
	}



static int dynamic_preferred(const char *target)
	{
	return 1;
	}



// targets by rank (index): ranked by performance, so that on a big.LITTLE
// CPU the target of the big cores is chosen
static const char *const armv8_rank_target[] = { NULL, "ARMV8A_ARM_CORTEX_A53", "ARMV8A_ARM_CORTEX_A55", "ARMV8A_ARM_CORTEX_A57", "ARMV8A_ARM_CORTEX_A73", "ARMV8A_ARM_CORTEX_A76", "ARMV8A_APPLE_M1" };

// rank of the target of a core, from the implementer and part number of its
// MIDR_EL1, 0 if unknown
static int armv8_rank(unsigned long long midr)
	{
	unsigned int implementer = (midr>>24) & 0xff;
	unsigned int part = (midr>>4) & 0xfff;
	if(implementer==0x61) // Apple
		return 6;
	if(implementer!=0x41) // Arm
		return 0;
	switch(part)
		{
		case 0xd03: // A53
		case 0xd04: // A35
			return 1;
		case 0xd05: // A55
		case 0xd46: // A510
		case 0xd80: // A520
		case 0xd88: // A520AE
			return 2;
		case 0xd07: // A57
		case 0xd08: // A72
			return 3;
		case 0xd09: // A73
		case 0xd0a: // A75
			return 4;
		}
	return part>=0xd0b ? 5 : 0; // A76 and later big cores, Neoverse
	}



static const char *dynamic_detected(void)
	{
	int ii, rank, best = 0;
	unsigned long long midr;
	char path[96];
	FILE *file;
	long ncpu = sysconf(_SC_NPROCESSORS_CONF);
	for(ii=0; ii<ncpu; ii++)
		{
		snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpu%d/regs/identification/midr_el1", ii);
		file = fopen(path, "r");
		if(file==NULL)
			continue;
		if(fscanf(file, "%llx", &midr)==1)
			{
			rank = armv8_rank(midr);
			if(rank>best)
				best = rank;
			}
		fclose(file);
		}
	if(best==0 && (getauxval(AT_HWCAP) & HWCAP_CPUID))
		{
		// emulated by the kernel; only the core running this thread
		__asm__ volatile("mrs %0, midr_el1" : "=r" (midr));
		best = armv8_rank(midr);
		}
	return armv8_rank_target[best];
	}

#elif defined(__arm__) && defined(__linux__)

#ifndef HWCAP_NEON
#define HWCAP_NEON (1 << 12)
#endif
#ifndef HWCAP_VFPv4
#define HWCAP_VFPv4 (1 << 16)
#endif

static void dynamic_cpu_init(void)
	{
	}



// CPU can run the target
static int dynamic_supported(const char *target)
	{
	unsigned long hwcap = getauxval(AT_HWCAP);
	if(!strcmp(target, "ARMV7A_ARM_CORTEX_A15") || !strcmp(target, "ARMV7A_ARM_CORTEX_A7"))
		return (hwcap & HWCAP_NEON) && (hwcap & HWCAP_VFPv4);
	if(!strcmp(target, "ARMV7A_ARM_CORTEX_A9"))
		return (hwcap & HWCAP_NEON)!=0;
	if(!strcmp(target, "GENERIC"))
		return 1;
	return 0;
	}



static int dynamic_preferred(const char *target)
	{
	return 1;
	}



// targets by rank (index): ranked by performance, so that on a big.LITTLE
// CPU the target of the big cores is chosen
static const char *const armv7_rank_target[] = { NULL, "ARMV7A_ARM_CORTEX_A7", "ARMV7A_ARM_CORTEX_A9", "ARMV7A_ARM_CORTEX_A15" };

// rank of the target of a core, from its implementer and part number, 0 if unknown
static int armv7_rank(unsigned int implementer, unsigned int part)
	{
	if(implementer!=0x41) // Arm
		return 0;
	switch(part)
		{
		case 0xc07: // A7
			return 1;
		case 0xc09: // A9
			return 2;
		case 0xc0d: // A12
		case 0xc0e: // A17
		case 0xc0f: // A15
			return 3;
		// ARMv8A cores running 32-bit code
		case 0xd03: // A53
		case 0xd04: // A35
		case 0xd05: // A55
		case 0xd46: // A510
		case 0xd80: // A520
			return 1;
		}
	return part>=0xd07 && part<0xe00 ? 3 : 0;
	}



static const char *dynamic_detected(void)
	{
	unsigned int implementer = 0, part;
	int rank, best = 0;
	char line[256];
	FILE *file = fopen("/proc/cpuinfo", "r");
	if(file==NULL)
		return NULL;
	while(fgets(line, sizeof(line), file)!=NULL)
		{
		if(sscanf(line, "CPU implementer : %x", &implementer)==1)
			continue;
		if(sscanf(line, "CPU part : %x", &part)==1)
			{
			rank = armv7_rank(implementer, part);
			if(rank>best)
				best = rank;
			}
		}
	fclose(file);
	return armv7_rank_target[best];
	}

#else
#error "TARGET=DYNAMIC: unsupported architecture"
#endif



static const char *dynamic_getenv(const char *name)
	{
#if defined(__linux__)
	return secure_getenv(name);
#elif defined(__APPLE__)
	return issetugid() ? NULL : getenv(name);
#else
	return getenv(name);
#endif
	}



// make the table read-only, if it fits the pages it is aligned and padded to
static void dynamic_protect(void)
	{
#if defined(_WIN32)
	SYSTEM_INFO info;
	DWORD old;
	GetSystemInfo(&info);
	if(info.dwPageSize>0 && BLASFEO_DYNAMIC_PAGE%info.dwPageSize==0)
		VirtualProtect(blasfeo_dynamic_table, sizeof(blasfeo_dynamic_table), PAGE_READONLY, &old);
#else
	long page = sysconf(_SC_PAGESIZE);
	if(page>0 && BLASFEO_DYNAMIC_PAGE%page==0)
		mprotect(blasfeo_dynamic_table, sizeof(blasfeo_dynamic_table), PROT_READ);
#endif
	}



// index of the target named (case insensitive) name or *_name, or -1
static int dynamic_find(const char *name)
	{
	int ii;
	for(ii=0; ii<BLASFEO_DYNAMIC_NARCH; ii++)
		{
		size_t lt = strlen(dynamic_targets[ii]), ln = strlen(name);
		if(!strcasecmp(dynamic_targets[ii], name))
			return ii;
		if(ln<lt && dynamic_targets[ii][lt-ln-1]=='_' && !strcasecmp(dynamic_targets[ii]+lt-ln, name))
			return ii;
		}
	return -1;
	}



// before the constructors of the user (static linking) and of any library
// depending on BLASFEO (dynamic linking: dependencies are initialized first),
// so that no matrix is laid out with the default panel size and then used
// with another one
#if defined(__APPLE__)
__attribute__((constructor)) // no priorities in Mach-O
#else
__attribute__((constructor(101)))
#endif
static void blasfeo_dynamic_init(void)
	{
	int ii;
	int sel = -1;
	const char *name;

	dynamic_cpu_init();

	name = dynamic_getenv("BLASFEO_TARGET");
	if(name!=NULL && name[0]!='\0')
		{
		sel = dynamic_find(name);
		if(sel<0)
			fprintf(stderr, "BLASFEO: BLASFEO_TARGET=%s is not a bundled target, ignored\n", name);
		else if(!dynamic_supported(dynamic_targets[sel]))
			{
			fprintf(stderr, "BLASFEO: BLASFEO_TARGET=%s is not supported by this CPU, ignored\n", name);
			sel = -1;
			}
		}

	if(sel<0)
		{
		name = dynamic_detected();
		if(name!=NULL)
			{
			sel = dynamic_find(name);
			if(sel>=0 && !dynamic_supported(dynamic_targets[sel]))
				sel = -1;
			}
		}

	for(ii=0; sel<0 && ii<BLASFEO_DYNAMIC_NARCH; ii++)
		if(dynamic_supported(dynamic_targets[ii]) && dynamic_preferred(dynamic_targets[ii]))
			sel = ii;
	for(ii=0; sel<0 && ii<BLASFEO_DYNAMIC_NARCH; ii++)
		if(dynamic_supported(dynamic_targets[ii]))
			sel = ii;
	if(sel<0)
		{
		fprintf(stderr, "BLASFEO: no bundled target is supported by this CPU, using %s\n", dynamic_targets[BLASFEO_DYNAMIC_NARCH-1]);
		sel = BLASFEO_DYNAMIC_NARCH-1;
		}

	dynamic_selected = sel;
	blasfeo_d_ps = dynamic_d_ps[sel];
	blasfeo_s_ps = dynamic_s_ps[sel];
	memcpy(blasfeo_dynamic_table, dynamic_impl[sel], sizeof(dynamic_impl[sel]));
	dynamic_protect();
	}

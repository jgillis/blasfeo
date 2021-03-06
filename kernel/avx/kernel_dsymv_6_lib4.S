/**************************************************************************************************
*                                                                                                 *
* This file is part of BLASFEO.                                                                   *
*                                                                                                 *
* BLASFEO -- BLAS For Embedded Optimization.                                                      *
* Copyright (C) 2016 by Gianluca Frison.                                                          *
* Developed at IMTEK (University of Freiburg) under the supervision of Moritz Diehl and at        *
* DTU Compute (Technical University of Denmark) under the supervision of John Bagterp Jorgensen.  *
* All rights reserved.                                                                            *
*                                                                                                 *
* HPMPC is free software; you can redistribute it and/or                                          *
* modify it under the terms of the GNU Lesser General Public                                      *
* License as published by the Free Software Foundation; either                                    *
* version 2.1 of the License, or (at your option) any later version.                              *
*                                                                                                 *
* HPMPC is distributed in the hope that it will be useful,                                        *
* but WITHOUT ANY WARRANTY; without even the implied warranty of                                  *
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                                            *
* See the GNU Lesser General Public License for more details.                                     *
*                                                                                                 *
* You should have received a copy of the GNU Lesser General Public                                *
* License along with HPMPC; if not, write to the Free Software                                    *
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA                  *
*                                                                                                 *
* Author: Gianluca Frison, giaf (at) dtu.dk                                                       *
*                          gianluca.frison (at) imtek.uni-freiburg.de                             *
*                                                                                                 *
**************************************************************************************************/

#define STACKSIZE 96

//.LSTR:
//	.string	"\n%d %d %d\n"

#if defined(OS_LINUX)
	.text
#elif defined(OS_MAC)
	.section	__TEXT,__text,regular,pure_instructions
#endif

// common inner routine with file scope
//
// input arguments:
// r10d  <- k
// r11   <- A
// r12   <- bs*sda*sizeof(double) = 32*sda
// r13   <- x_t
// r14   <- z_n
// ymm0  <- [z_t_0a z_t_0b z_t_0c z_t_0d]
// ymm1  <- [z_t_1a z_t_1b z_t_1c z_t_1d]
// ymm2  <- [z_t_2a z_t_2b z_t_2c z_t_2d]
// ymm3  <- [z_t_3a z_t_3b z_t_3c z_t_3d]
// ymm4  <- [z_t_4a z_t_4b z_t_4c z_t_4d]
// ymm5  <- [z_t_5a z_t_5b z_t_5c z_t_5d]
// ymm6  <- x_n_0
// ymm7  <- x_n_1
// ymm8  <- x_n_2
// ymm9  <- x_n_3
// ymm10 <- x_n_4
// ymm11 <- x_n_5
// ymm12 <- dirty
// ymm13 <- dirty
// ymm14 <- dirty
// ymm15 <- dirty

//
// output arguments:
// r10d  <- 0
// r11   <- A+4*k*sizeof(double)
// r12   <- bs*sda*sizeof(double) = 32*sda
// r13   <- x_t+k*sizeof(double)
// r14   <- z_n+k*sizeof(double)
// ymm0  <- [z_t_0a z_t_0b z_t_0c z_t_0d]
// ymm1  <- [z_t_1a z_t_1b z_t_1c z_t_1d]
// ymm2  <- [z_t_2a z_t_2b z_t_2c z_t_2d]
// ymm3  <- [z_t_3a z_t_3b z_t_3c z_t_3d]
// ymm4  <- [z_t_4a z_t_4b z_t_4c z_t_4d]
// ymm5  <- [z_t_5a z_t_5b z_t_5c z_t_5d]
// ymm6  <- x_n_0
// ymm7  <- x_n_1
// ymm8  <- x_n_2
// ymm9  <- x_n_3
// ymm10 <- x_n_4
// ymm11 <- x_n_5
// ymm12 <- dirty
// ymm13 <- dirty
// ymm14 <- dirty
// ymm15 <- dirty

#if MACRO_LEVEL>=2
	.macro INNER_KERNEL_DGEMV_ADD_NT_6_LIB4
#else
	.p2align 4,,15
#if defined(OS_LINUX)
	.type inner_kernel_dgemv_add_nt_6_lib4, @function
inner_kernel_dgemv_add_nt_6_lib4:
#elif defined(OS_MAC)
_inner_kernel_dgemv_add_nt_6_lib4:
#endif
#endif

	cmpl	$0, %r10d
	jle		2f // return

	cmpl	$4, %r10d
	jl		0f // clean-up loop

	// main loop
	.p2align 3
1: // main loop
	
	vmovupd	0(%r13), %ymm12
	vmovupd	0(%r14), %ymm13

	vmovapd	0(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm0, %ymm15, %ymm0
	vmulpd	%ymm14, %ymm6, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	subl	$4, %r10d

	vmovapd	32(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm1, %ymm15, %ymm1
	vmulpd	%ymm14, %ymm7, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	vmovapd	64(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm2, %ymm15, %ymm2
	vmulpd	%ymm14, %ymm8, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13

	vmovapd	96(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm3, %ymm15, %ymm3
	vmulpd	%ymm14, %ymm9, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	vmovapd	128(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm4, %ymm15, %ymm4
	vmulpd	%ymm14, %ymm10, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	vmovapd	160(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm5, %ymm15, %ymm5
	vmulpd	%ymm14, %ymm11, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	vmovupd	%ymm13, 0(%r14) 

	addq	%r12, %r11
	addq	$32, %r13
	addq	$32, %r14
	
	cmpl	$3, %r10d

	jg		1b // main loop 


	// consider clean-up
	cmpl	$0, %r10d
	jle		2f // return

0: // clean-up
	
	vcvtsi2sd	%r10d, %xmm14, %xmm14
#if defined(OS_LINUX)
	vmovupd		.LC02(%rip), %ymm13
#elif defined(OS_MAC)
	vmovupd		LC02(%rip), %ymm13
#endif
	vmovddup	%xmm14, %xmm14
	vinsertf128	$1, %xmm14, %ymm14, %ymm14
	vsubpd		%ymm14, %ymm13, %ymm14

	vmaskmovpd	0(%r13), %ymm14, %ymm12
	vmaskmovpd	0(%r14), %ymm14, %ymm13

	vmovapd	0(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm0, %ymm15, %ymm0
	vmulpd	%ymm14, %ymm6, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	vmovapd	32(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm1, %ymm15, %ymm1
	vmulpd	%ymm14, %ymm7, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	vmovapd	64(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm2, %ymm15, %ymm2
	vmulpd	%ymm14, %ymm8, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13

	vmovapd	96(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm3, %ymm15, %ymm3
	vmulpd	%ymm14, %ymm9, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
		
	vmovapd	128(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm4, %ymm15, %ymm4
	vmulpd	%ymm14, %ymm10, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	vmovapd	160(%r11), %ymm14
	vmulpd	%ymm14, %ymm12, %ymm15
	vaddpd	%ymm5, %ymm15, %ymm5
	vmulpd	%ymm14, %ymm11, %ymm15
	vaddpd	%ymm13, %ymm15, %ymm13
	
	vcvtsi2sd	%r10d, %xmm14, %xmm14
#if defined(OS_LINUX)
	vmovupd		.LC02(%rip), %ymm15
#elif defined(OS_MAC)
	vmovupd		LC02(%rip), %ymm15
#endif
	vmovddup	%xmm14, %xmm14
	vinsertf128	$1, %xmm14, %ymm14, %ymm14
	vsubpd		%ymm14, %ymm15, %ymm14

	vmaskmovpd	%ymm13, %ymm14, 0(%r14)

	sall	$3, %r10d
	movslq	%r10d, %r10
	addq	%r10, %r11
	addq	%r10, %r13
	addq	%r10, %r14
	xorl	%r10d, %r10d
	
	
2: // return

#if MACRO_LEVEL>=2
	.endm
#else
	ret

#if defined(OS_LINUX)
	.size	inner_kernel_dgemv_add_nt_6_lib4, .-inner_kernel_dgemv_add_nt_6_lib4
#endif
#endif






#if 0

// TODO
// common inner routine with file scope
//
// input arguments:
// r10   <- kmax
// r11   <- A
// r12   <- bs*sda*sizeof(double) = 32*sda
// r13   <- x_t
// r14   <- z_n
// ymm0  <- [z_t_0a z_t_0b z_t_0c z_t_0d]
// ymm1  <- [z_t_1a z_t_1b z_t_1c z_t_1d]
// ymm2  <- [z_t_2a z_t_2b z_t_2c z_t_2d]
// ymm3  <- [z_t_3a z_t_3b z_t_3c z_t_3d]
// ymm6  <- x_n_0
// ymm7  <- x_n_1
// ymm8  <- x_n_2
// ymm9  <- x_n_3
// ymm10 <- dirty
// ymm11 <- dirty
// ymm12 <- dirty
// ymm13 <- dirty
// ymm14 <- dirty
// ymm15 <- dirty

//
// output arguments:
// r10   <- kmax-4
// r11   <- A+4*k*sizeof(double)
// r12   <- bs*sda*sizeof(double) = 32*sda
// r13   <- x_t+k*sizeof(double)
// r14   <- z_n+k*sizeof(double)
// ymm0  <- [z_t_0a z_t_0b z_t_0c z_t_0d]
// ymm1  <- [z_t_1a z_t_1b z_t_1c z_t_1d]
// ymm2  <- [z_t_2a z_t_2b z_t_2c z_t_2d]
// ymm3  <- [z_t_3a z_t_3b z_t_3c z_t_3d]
// ymm6  <- x_n_0
// ymm7  <- x_n_1
// ymm8  <- x_n_2
// ymm9  <- x_n_3
// ymm10 <- dirty
// ymm11 <- dirty
// ymm12 <- dirty
// ymm13 <- dirty
// ymm14 <- dirty
// ymm15 <- dirty

#if MACRO_LEVEL>=2
	.macro INNER_EDGE_DSYMV_ADD_NT_4_LIB4
#else
	.p2align 4,,15
#if defined(OS_LINUX)
	.type inner_edge_dsymv_add_nt_4_lib4, @function
inner_edge_dsymv_add_nt_4_lib4:
#elif defined(OS_MAC)
_inner_edge_dsymv_add_nt_4_lib4:
#endif
#endif

	vmovupd		0(%r13), %ymm12
	vmovupd		0(%r14), %ymm13

	vmovapd		0(%r11), %ymm14
	vmulpd		%ymm14, %ymm12, %ymm15
	vaddpd		%ymm0, %ymm15, %ymm0
	vxorpd		%ymm15, %ymm15, %ymm15
	vblendpd	$0x1, %ymm15, %ymm14, %ymm14
	vmulpd		%ymm14, %ymm6, %ymm15
	vaddpd		%ymm13, %ymm15, %ymm13
	
	vmovapd		32(%r11), %ymm14
	vxorpd		%ymm15, %ymm15, %ymm15
	vblendpd	$0x1, %ymm15, %ymm14, %ymm14
	vmulpd		%ymm14, %ymm12, %ymm15
	vaddpd		%ymm1, %ymm15, %ymm1
	vxorpd		%ymm15, %ymm15, %ymm15
	vblendpd	$0x3, %ymm15, %ymm14, %ymm14
	vmulpd		%ymm14, %ymm7, %ymm15
	vaddpd		%ymm13, %ymm15, %ymm13
	
	vmovapd		64(%r11), %ymm14
	vxorpd		%ymm15, %ymm15, %ymm15
	vblendpd	$0x3, %ymm15, %ymm14, %ymm14
	vmulpd		%ymm14, %ymm12, %ymm15
	vaddpd		%ymm2, %ymm15, %ymm2
	vxorpd		%ymm15, %ymm15, %ymm15
	vblendpd	$0x7, %ymm15, %ymm14, %ymm14
	vmulpd		%ymm14, %ymm8, %ymm15
	vaddpd		%ymm13, %ymm15, %ymm13

	vmovapd		96(%r11), %ymm14
	vxorpd		%ymm15, %ymm15, %ymm15
	vblendpd	$0x7, %ymm15, %ymm14, %ymm14
	vmulpd		%ymm14, %ymm12, %ymm15
	vaddpd		%ymm3, %ymm15, %ymm3
//	vxorpd		%ymm15, %ymm15, %ymm15
//	vblendpd	$0x0, %ymm14, %ymm15, %ymm14
//	vmulpd		%ymm14, %ymm9, %ymm15
//	vaddpd		%ymm13, %ymm15, %ymm13
	
	vmovupd		%ymm13, 0(%r14) 

	addq	%r12, %r11
	addq	$32, %r13
	addq	$32, %r14
	
	subq	$4, %r10

#if MACRO_LEVEL>=2
	.endm
#else
	ret

#if defined(OS_LINUX)
	.size	inner_edge_dsymv_add_nt_4_lib4, .-inner_edge_dsymv_add_nt_4_lib4
#endif
#endif

#endif





// common inner routine with file scope
//
// blend for ta==t, scale for generic alpha and beta
//
// input arguments:
// r10  <- alpha
// r11  <- beta
// r12  <- y
// ymm0 <- [z0a z0b z0c z0d]
// ymm1 <- [z1a z1b z1c z1d]
// ymm2 <- [z2a z2b z2c z2d]
// ymm3 <- [z3a z3b z3c z3d]
// ymm4 <- [z4a z4b z4c z4d]
// ymm5 <- [z5a z5b z5c z5d]
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm15 <- dirty
//
// output arguments:
// r10  <- alpha
// r11  <- beta
// r12  <- y
// ymm0 <- [z0 z1 z2 z3]
// ymm1 <- [z4 z5 xx xx]
// ymm1 <- dirty
// ymm2 <- dirty
// ymm3 <- dirty
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm15 <- dirty

#if MACRO_LEVEL>=1
	.macro INNER_BLEND_T_SCALE_AB_6_LIB4
#else
	.p2align 4,,15
#if defined(OS_LINUX)
	.type inner_blend_t_scale_ab_6_lib4, @function
inner_blend_t_scale_ab_6_lib4:
#elif defined(OS_MAC)
_inner_blend_t_scale_ab_6_lib4:
#endif
#endif

	// reduction
	vhaddpd			%ymm1, %ymm0, %ymm0
	vhaddpd			%ymm3, %ymm2, %ymm2
	vhaddpd			%ymm5, %ymm4, %ymm4
//	vhaddpd			%ymm3, %ymm2, %ymm2
	vperm2f128		$0x2, %ymm0, %ymm2, %ymm1
	vperm2f128		$0x13, %ymm0, %ymm2, %ymm0
	vextractf128	$0x1, %ymm4, %xmm5
	vaddpd			%ymm0, %ymm1, %ymm0
	vaddpd			%ymm4, %ymm5, %ymm4

	// alpha
	vbroadcastsd	0(%r10), %ymm15
	vmulpd			%ymm0, %ymm15, %ymm0
	vmulpd			%ymm4, %ymm15, %ymm1

	// beta
	vbroadcastsd	0(%r11), %ymm15
	vmovupd			0(%r12), %ymm14
	vmovupd			32(%r12), %ymm13
	vmulpd			%ymm15, %ymm14, %ymm14
	vaddpd			%ymm0, %ymm14, %ymm0
	vmulpd			%ymm15, %ymm13, %ymm13
	vaddpd			%ymm1, %ymm13, %ymm1
	
	vxorpd			%ymm15, %ymm15, %ymm15
	vblendpd		$0x3, %ymm1, %ymm15, %ymm1

#if MACRO_LEVEL>=1
	.endm
#else
	ret
	
#if defined(OS_LINUX)
	.size	inner_blend_t_scale_ab_6_lib4, .-inner_blend_t_scale_ab_6_lib4
#endif
#endif





#if 0

//TODO
// common inner routine with file scope
//
// blend for ta==t, scale for generic alpha and beta=1.0
//
// input arguments:
// r10  <- alpha
// r11  <- y
// ymm0 <- [z0a z0b z0c z0d]
// ymm1 <- [z1a z1b z1c z1d]
// ymm2 <- [z2a z2b z2c z2d]
// ymm3 <- [z3a z3b z3c z3d]
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm15 <- dirty
//
// output arguments:
// r10  <- alpha
// r11  <- y
// ymm0 <- [z0 z1 z2 z3]
// ymm1 <- dirty
// ymm2 <- dirty
// ymm3 <- dirty
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm15 <- dirty

#if MACRO_LEVEL>=1
	.macro INNER_BLEND_T_SCALE_A1_4_LIB4
#else
	.p2align 4,,15
#if defined(OS_LINUX)
	.type inner_blend_t_scale_a1_4_lib4, @function
inner_blend_t_scale_a1_4_lib4:
#elif defined(OS_MAC)
_inner_blend_t_scale_a1_4_lib4:
#endif
#endif

	// reduction
	vhaddpd	%ymm1, %ymm0, %ymm0
	vhaddpd	%ymm3, %ymm2, %ymm2
	vperm2f128	$0x2, %ymm0, %ymm2, %ymm1
	vperm2f128	$0x13, %ymm0, %ymm2, %ymm0
	vaddpd	%ymm0, %ymm1, %ymm0

	// alpha
	vbroadcastsd	0(%r10), %ymm15
	vmulpd	%ymm0, %ymm15, %ymm0

	// beta
	vmovupd		0(%r11), %ymm14
	vaddpd		%ymm0, %ymm14, %ymm0
	
#if MACRO_LEVEL>=1
	.endm
#else
	ret
	
#if defined(OS_LINUX)
	.size	inner_blend_t_scale_a1_4_lib4, .-inner_blend_t_scale_a1_4_lib4
#endif
#endif

#endif




// common inner routine with file scope
//
// store 
//
// input arguments:
// r10  <- z
// ymm0 <- [z0 z1 z2 z3]
//
// output arguments:
// r10  <- z
// ymm0 <- [z0 z1 z2 z3]

#if MACRO_LEVEL>=1
	.macro INNER_STORE_6_LIB4
#else
	.p2align 4,,15
#if defined(OS_LINUX)
	.type inner_store_6_lib4, @function
inner_store_6_lib4:
#elif defined(OS_MAC)
_inner_store_6_lib4:
#endif
#endif
	
	vmovupd %ymm0, 0(%r10)
	vmovupd %xmm1, 32(%r10)
	
#if MACRO_LEVEL>=1
	.endm
#else
	ret

#if defined(OS_LINUX)
	.size	inner_store_6_lib4, .-inner_store_6_lib4
#endif
#endif





//                             rdi    rsi              rdx              rcx        r8       r9           rsp+8        rsp+16          rsp+24       rsp_32       rsp_40
// void kernel_dgemv_nt_6_lib4(int k, double *alpha_n, double *alpha_t, double *A, int sda, double *x_n, double *x_t, double *beta_t, double *y_t, double *z_n, double *z_t);

	.p2align 4,,15
#if defined(OS_LINUX)
	.globl kernel_dgemv_nt_6_lib4
	.type kernel_dgemv_nt_6_lib4, @function
kernel_dgemv_nt_6_lib4:
#elif defined(OS_MAC)
	.globl _kernel_dgemv_nt_6_lib4
_kernel_dgemv_nt_6_lib4:
#endif
	
	// prologue

	subq	$STACKSIZE, %rsp
	movq	%rbx,   (%rsp)
	movq	%rbp,  8(%rsp)
	movq	%r12, 16(%rsp)
	movq	%r13, 24(%rsp)
	movq	%r14, 32(%rsp)
	movq	%r15, 40(%rsp)

	vzeroupper


	// zero accumulation registers y_t

	vxorpd	%ymm0, %ymm0, %ymm0
	vmovapd	%ymm0, %ymm1
	vmovapd	%ymm0, %ymm2
	vmovapd	%ymm0, %ymm3
	vmovapd	%ymm0, %ymm4
	vmovapd	%ymm0, %ymm5

	// initialize x_n
	movq	%rsi, %r10 // alpha_n
	vbroadcastsd 0(%r10), %ymm15

	movq	%r9, %r10 // x_n

	vbroadcastsd 0(%r10), %ymm6
	vmulpd		%ymm15, %ymm6, %ymm6
	vbroadcastsd 8(%r10), %ymm7
	vmulpd		%ymm15, %ymm7, %ymm7
	vbroadcastsd 16(%r10), %ymm8
	vmulpd		%ymm15, %ymm8, %ymm8
	vbroadcastsd 24(%r10), %ymm9
	vmulpd		%ymm15, %ymm9, %ymm9
	vbroadcastsd 32(%r10), %ymm10
	vmulpd		%ymm15, %ymm10, %ymm10
	vbroadcastsd 40(%r10), %ymm11
	vmulpd		%ymm15, %ymm11, %ymm11


	// inner kernel dgemv nt

	movl	%edi, %r10d // k
	movq	%rcx, %r11  // A
	movl	%r8d, %r12d // sda
	sall	$5, %r12d // 4*sda*sizeof(double)
//	movslq	%r12d, %r12
	movq	STACKSIZE +  8(%rsp), %r13  // x_t
	movq	STACKSIZE + 32(%rsp), %r14  // z_n

#if MACRO_LEVEL>=2
	INNER_KERNEL_DGEMV_ADD_NT_6_LIB4
#else
#if defined(OS_LINUX)
	call inner_kernel_dgemv_add_nt_6_lib4
#elif defined(OS_MAC)
	callq _inner_kernel_dgemv_add_nt_6_lib4
#endif
#endif


	// inner blend n scale ab

	movq	%rdx, %r10 // alpha_t
	movq	STACKSIZE + 16(%rsp), %r11   // beta_t
	movq	STACKSIZE + 24(%rsp), %r12   // y_t

#if MACRO_LEVEL>=1
	INNER_BLEND_T_SCALE_AB_6_LIB4
#else
#if defined(OS_LINUX)
	call inner_blend_t_scale_ab_6_lib4
#elif defined(OS_MAC)
	callq _inner_blend_t_scale_ab_6_lib4
#endif
#endif


	// store

	movq	STACKSIZE + 40(%rsp), %r10 // z_t 

#if MACRO_LEVEL>=1
	INNER_STORE_6_LIB4
#else
#if defined(OS_LINUX)
	call inner_store_6_lib4
#elif defined(OS_MAC)
	callq _inner_store_6_lib4
#endif
#endif


	// epilogue

	vzeroupper

	movq	  (%rsp), %rbx 
	movq	 8(%rsp), %rbp
	movq	16(%rsp), %r12 
	movq	24(%rsp), %r13 
	movq	32(%rsp), %r14 
	movq	40(%rsp), %r15 
	addq	$STACKSIZE, %rsp

	ret

#if defined(OS_LINUX)
	.size	kernel_dgemv_nt_6_lib4, .-kernel_dgemv_nt_6_lib4
#endif





#if 0
// TODO
//                            rdi    rsi            rdx        rcx      r8           r9           rsp+8        rsp+16 
// void kernel_dsymv_l_4_lib4(int k, double *alpha, double *A, int sda, double *x_n, double *x_t, double *z_n, double *z_t);

	.p2align 4,,15
#if defined(OS_LINUX)
	.globl kernel_dsymv_l_4_lib4
	.type kernel_dsymv_l_4_lib4, @function
kernel_dsymv_l_4_lib4:
#elif defined(OS_MAC)
	.globl _kernel_dsymv_l_4_lib4
_kernel_dsymv_l_4_lib4:
#endif
	
	// prologue

	subq	$STACKSIZE, %rsp
	movq	%rbx,   (%rsp)
	movq	%rbp,  8(%rsp)
	movq	%r12, 16(%rsp)
	movq	%r13, 24(%rsp)
	movq	%r14, 32(%rsp)
	movq	%r15, 40(%rsp)

	vzeroupper


	// zero accumulation registers y_t

	vxorpd	%ymm0, %ymm0, %ymm0
	vmovapd	%ymm0, %ymm1
	vmovapd	%ymm0, %ymm2
	vmovapd	%ymm0, %ymm3

	// initialize x_n
	movq	%rsi, %r10 // alpha
	vbroadcastsd 0(%r10), %ymm15

	movq	%r8, %r10 // x_n

	vbroadcastsd 0(%r10), %ymm6
	vmulpd		%ymm15, %ymm6, %ymm6
	vbroadcastsd 8(%r10), %ymm7
	vmulpd		%ymm15, %ymm7, %ymm7
	vbroadcastsd 16(%r10), %ymm8
	vmulpd		%ymm15, %ymm8, %ymm8
	vbroadcastsd 24(%r10), %ymm9
	vmulpd		%ymm15, %ymm9, %ymm9


	// inner edge dsyrk & kernel dgemv nt

	movl	%edi, %r10d // k
	movq	%rdx, %r11  // A
	movl	%ecx, %r12d // sda
	sall	$5, %r12d // 4*sda*sizeof(double)
//	movslq	%r12d, %r12
	movq	%r9, %r13  // x_t
	movq	STACKSIZE + 8(%rsp), %r14  // z_n

#if MACRO_LEVEL>=2
	INNER_EDGE_DSYMV_ADD_NT_4_LIB4
#else
#if defined(OS_LINUX)
	call inner_edge_dsymv_add_nt_4_lib4
#elif defined(OS_MAC)
	callq _inner_edge_dsymv_add_nt_4_lib4
#endif
#endif

#if MACRO_LEVEL>=2
	INNER_KERNEL_DGEMV_ADD_NT_4_LIB4
#else
#if defined(OS_LINUX)
	call inner_kernel_dgemv_add_nt_4_lib4
#elif defined(OS_MAC)
	callq _inner_kernel_dgemv_add_nt_4_lib4
#endif
#endif


	// call inner blend n scale ab

	movq	%rsi, %r10 // alpha
	movq	STACKSIZE + 16(%rsp), %r11   // z_t

#if MACRO_LEVEL>=1
	INNER_BLEND_T_SCALE_A1_4_LIB4
#else
#if defined(OS_LINUX)
	call inner_blend_t_scale_a1_4_lib4
#elif defined(OS_MAC)
	callq _inner_blend_t_scale_a1_4_lib4
#endif
#endif


	// store

	movq	STACKSIZE + 16(%rsp), %r10 // z_t 

#if MACRO_LEVEL>=1
	INNER_STORE_4_LIB4
#else
#if defined(OS_LINUX)
	call inner_store_4_lib4
#elif defined(OS_MAC)
	callq _inner_store_4_lib4
#endif
#endif


	// epilogue

	vzeroupper

	movq	  (%rsp), %rbx 
	movq	 8(%rsp), %rbp
	movq	16(%rsp), %r12 
	movq	24(%rsp), %r13 
	movq	32(%rsp), %r14 
	movq	40(%rsp), %r15 
	addq	$STACKSIZE, %rsp

	ret

#if defined(OS_LINUX)
	.size	kernel_dsymv_l_4_lib4, .-kernel_dsymv_l_4_lib4
#endif

#endif





	// read-only data
#if defined(OS_LINUX)
	.section	.rodata.cst32,"aM",@progbits,32
#elif defined(OS_MAC)
	.section	__TEXT,__const
#endif
#if 1
#if defined(OS_LINUX)
	.align 32
.LC00: // { -1 -1 -1 1 }
#elif defined(OS_MAC)
LC00: // { -1 -1 -1 1 }
	.align 5
#endif
	.quad	-1
	.quad	-1
	.quad	-1
	.quad	1
#if defined(OS_LINUX)
	.align 32
.LC01: // { -1 -1 -1 -1 }
#elif defined(OS_MAC)
LC01: // { -1 -1 -1 -1 }
	.align 5
#endif
	.quad	-1
	.quad	-1
	.quad	-1
	.quad	-1
#endif
#if defined(OS_LINUX)
	.align 32
.LC02: // { 3.5 2.5 1.5 0.5 }
#elif defined(OS_MAC)
LC02: // { 3.5 2.5 1.5 0.5 }
	.align 5
#endif
	.long	0
	.long	1071644672
	.long	0
	.long	1073217536
	.long	0
	.long	1074003968
	.long	0
	.long	1074528256
#if defined(OS_LINUX)
	.align 32
.LC03: // { 7.5 6.5 5.5 4.5 }
#elif defined(OS_MAC)
LC03: // { 7.5 6.5 5.5 4.5 }
	.align 5
#endif
	.long	0
	.long	1074921472
	.long	0
	.long	1075183616
	.long	0
	.long	1075445760
	.long	0
	.long	1075707904
#if defined(OS_LINUX)
	.align 32
.LC04: // { 1.0 1.0 1.0 1.0 }
#elif defined(OS_MAC)
LC04: // { 1.0 1.0 1.0 1.0 }
	.align 5
#endif
	.long	0
	.long	1072693248
	.long	0
	.long	1072693248
	.long	0
	.long	1072693248
	.long	0
	.long	1072693248



#if defined(OS_LINUX)
	.section	.note.GNU-stack,"",@progbits
#elif defined(OS_MAC)
	.subsections_via_symbols
#endif






/**************************************************************************************************
*                                                                                                 *
* This file is part of BLASFEO.                                                                   *
*                                                                                                 *
* BLASFEO -- BLAS For Embedded Optimization.                                                      *
* Copyright (C) 2016 by Gianluca Frison. All rights reserved.                                     *
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

// 

#define STACKSIZE 96

//.LSTR:
//	.string	"\n%d %d %d\n"

	.text

// common inner routine with file scope
//
// input arguments:
// r10d  <- k
// r11   <- A
// r12   <- 4*sda*sizeof(double)
// r13   <- x
// r15   <- dirty
// ymm0  <- [z0 z1 z2 z3]_a
// ymm1  <- [z4 z5 z6 z7]_a
// ymm2  <- [z0 z1 z2 z3]_b
// ymm3  <- [z4 z5 z6 z7]_b
// ymm4  <- [z0 z1 z2 z3]_c
// ymm5  <- [z4 z5 z6 z7]_c
// ymm6  <- [z0 z1 z2 z3]_d
// ymm7  <- [z4 z5 z6 z7]_d
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm12 <- dirty
// ymm13 <- dirty
// ymm14 <- dirty
// ymm15 <- dirty

//
// output arguments:
// r10d  <- 0
// r11   <- A+4*k*sizeof(double)
// r12   <- 4*sda*sizeof(double)
// r13   <- x+k*sizeof(double)
// r15   <- dirty
// ymm0  <- [z0 z1 z2 z3]_a
// ymm1  <- [z4 z5 z6 z7]_a
// ymm2  <- [z0 z1 z2 z3]_b
// ymm3  <- [z4 z5 z6 z7]_b
// ymm4  <- [z0 z1 z2 z3]_c
// ymm5  <- [z4 z5 z6 z7]_c
// ymm6  <- [z0 z1 z2 z3]_d
// ymm7  <- [z4 z5 z6 z7]_d
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm12 <- dirty
// ymm13 <- dirty
// ymm14 <- dirty
// ymm15 <- dirty

	.p2align 4,,15
	.type inner_kernel_dgemv_add_n_8_lib4, @function
inner_kernel_dgemv_add_n_8_lib4:
	
	cmpl	$0, %r10d
	jle		.L002 // return

	movq	%r11, %r15 // A1 <- A0
	addq	%r12, %r15 // A1 <- A0 + 4*sda*sizeof(double)

	cmpl	$4, %r10d
	jl		.L000 // clean-up loop

	// main loop
	.p2align 3
.L001: // main loop
	
	vbroadcastsd	0(%r13), %ymm12
	vmovapd	0(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm0
	vmovapd	0(%r15), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm1
	
	subl	$4, %r10d

	vbroadcastsd	8(%r13), %ymm12
	vmovapd	32(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm2
	vmovapd	32(%r15), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm3
	
	vbroadcastsd	16(%r13), %ymm12
	vmovapd	64(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm4
	vmovapd	64(%r15), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm5

	vbroadcastsd	24(%r13), %ymm12
	addq	$32, %r13
	vmovapd	96(%r11), %ymm8
	addq	$128, %r11
	vfmadd231pd	%ymm8, %ymm12, %ymm6
	vmovapd	96(%r15), %ymm8
	addq	$128, %r15
	vfmadd231pd	%ymm8, %ymm12, %ymm7
	
	cmpl	$3, %r10d

	jg		.L001 // main loop 


	// consider clean-up
	cmpl	$0, %r10d
	jle		.L002 // return

.L000: // clean-up
	
	vbroadcastsd	0(%r13), %ymm12
	vmovapd	0(%r11), %ymm8
	vmulpd	%ymm8, %ymm12, %ymm15
	vaddpd	%ymm0, %ymm15, %ymm0
	vmovapd	0(%r15), %ymm8
	vmulpd	%ymm8, %ymm12, %ymm15
	vaddpd	%ymm1, %ymm15, %ymm1
	
	addq	$32, %r11
	addq	$32, %r15
	addq	$8, %r13
	
	subl	$1, %r10d
	cmpl	$0, %r10d

	jg		.L000 // clean

.L002: // return

	ret

	.size	inner_kernel_dgemv_add_n_8_lib4, .-inner_kernel_dgemv_add_n_8_lib4





// common inner routine with file scope
//
// input arguments:
// r10d  <- k
// r11   <- A
// r12   <- bs*sda*sizeof(double) = 32*sda
// r13   <- x
// ymm0  <- [z0a z0b z0c z0d]
// ymm1  <- [z1a z1b z1c z1d]
// ymm2  <- [z2a z2b z2c z2d]
// ymm3  <- [z3a z3b z3c z3d]
// ymm4  <- [z4a z4b z4c z4d]
// ymm5  <- [z5a z5b z5c z5d]
// ymm6  <- [z6a z6b z6c z6d]
// ymm7  <- [z7a z7b z7c z7d]
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm12 <- dirty
// ymm13 <- dirty
// ymm14 <- dirty
// ymm15 <- dirty

//
// output arguments:
// r10d  <- 0
// r11   <- A+4*k*sizeof(double)
// r12   <- bs*sda*sizeof(double) = 32*sda
// r13   <- x+k*sizeof(double)
// ymm0  <- [z0a z0b z0c z0d]
// ymm1  <- [z1a z1b z1c z1d]
// ymm2  <- [z2a z2b z2c z2d]
// ymm3  <- [z3a z3b z3c z3d]
// ymm4  <- [z4a z4b z4c z4d]
// ymm5  <- [z5a z5b z5c z5d]
// ymm6  <- [z6a z6b z6c z6d]
// ymm7  <- [z7a z7b z7c z7d]
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm12 <- dirty
// ymm13 <- dirty
// ymm14 <- dirty
// ymm15 <- dirty

	.p2align 4,,15
	.type inner_kernel_dgemv_add_t_8_lib4, @function
inner_kernel_dgemv_add_t_8_lib4:

	cmpl	$0, %r10d
	jle		.L007 // return

	cmpl	$4, %r10d
	jl		.L005 // clean-up loop

	// main loop
	.p2align 3
.L006: // main loop
	
	vmovapd	0(%r13), %ymm12

	vmovapd	0(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm0
	
	subl	$4, %r10d

	vmovapd	32(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm1
	
	vmovapd	64(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm2

	vmovapd	96(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm3

	vmovapd	128(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm4
	
	vmovapd	160(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm5
	
	vmovapd	192(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm6

	vmovapd	224(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm7
	
	addq	%r12, %r11
	addq	$32, %r13
	
	cmpl	$3, %r10d

	jg		.L006 // main loop 


	// consider clean-up
	cmpl	$0, %r10d
	jle		.L007 // return

.L005: // clean-up
	
	vcvtsi2sd	%r10d, %xmm14, %xmm14
	vmovupd		.LC02(%rip), %ymm13
	vmovddup	%xmm14, %xmm14
	vinsertf128	$1, %xmm14, %ymm14, %ymm14
	vsubpd		%ymm14, %ymm13, %ymm14

	vmaskmovpd	0(%r13), %ymm14, %ymm12

	vmovapd	0(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm0
	
	vmovapd	32(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm1
	
	vmovapd	64(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm2

	vmovapd	96(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm3
		
	vmovapd	128(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm4
	
	vmovapd	160(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm5
	
	vmovapd	192(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm6

	vmovapd	224(%r11), %ymm8
	vfmadd231pd	%ymm8, %ymm12, %ymm7

	sall	$3, %r10d
	movslq	%r10d, %r10
	addq	%r10, %r11
	addq	%r10, %r13
	xorl	%r10d, %r10d
	
	
.L007: // return

	ret

	.size	inner_kernel_dgemv_add_t_8_lib4, .-inner_kernel_dgemv_add_t_8_lib4





// common inner routine with file scope
//
// blender for ta==n
//
// input arguments:
// r10d <- alg
// r11   <- y
// ymm0 <- [z0 z1 z2 z3]_a
// ymm1 <- [z4 z5 z6 z7]_a
// ymm2 <- [z0 z1 z2 z3]_b
// ymm3 <- [z4 z5 z6 z7]_b
// ymm4 <- [z0 z1 z2 z3]_c
// ymm5 <- [z4 z5 z6 z7]_c
// ymm6 <- [z0 z1 z2 z3]_d
// ymm7 <- [z4 z5 z6 z7]_d
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm15 <- dirty
//
// output arguments:
// r10d <- alg
// r11   <- y
// ymm0 <- [z0 z1 z2 z3]
// ymm1 <- [z4 z5 z6 z7]
// ymm2 <- dirty
// ymm3 <- dirty
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm15 <- dirty

	.p2align 4,,15
	.type inner_blender_n_8_lib4, @function
inner_blender_n_8_lib4:

	// reduction
	vaddpd	%ymm0, %ymm2, %ymm0
	vaddpd	%ymm1, %ymm3, %ymm1
	vaddpd	%ymm4, %ymm6, %ymm4
	vaddpd	%ymm5, %ymm7, %ymm5
	vaddpd	%ymm0, %ymm4, %ymm0
	vaddpd	%ymm1, %ymm5, %ymm1

	cmpl	$0, %r10d // alg
	je		.L003 // return

	cmpl	$1, %r10d // alg
	jne		.L004 // alg==-1

	// alg==1
	vmovupd		0(%r11), %ymm15
	vaddpd		%ymm0, %ymm15, %ymm0
	vmovupd		32(%r11), %ymm15
	vaddpd		%ymm1, %ymm15, %ymm1

	ret // return

.L004:

	// alg==-1
	vmovupd		0(%r11), %ymm15
	vsubpd		%ymm0, %ymm15, %ymm0
	vmovupd		32(%r11), %ymm15
	vsubpd		%ymm1, %ymm15, %ymm1

.L003: // return
	
	ret
	
	.size	inner_blender_n_8_lib4, .-inner_blender_n_8_lib4





// common inner routine with file scope
//
// blender for ta==t
//
// input arguments:
// r10d <- alg
// r11   <- y
// ymm0 <- [z0a z0b z0c z0d]
// ymm1 <- [z1a z1b z1c z1d]
// ymm2 <- [z2a z2b z2c z2d]
// ymm3 <- [z3a z3b z3c z3d]
// ymm0 <- [z4a z4b z4c z4d]
// ymm1 <- [z5a z5b z5c z5d]
// ymm2 <- [z6a z6b z6c z6d]
// ymm3 <- [z7a z7b z7c z7d]
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm15 <- dirty
//
// output arguments:
// r10d <- alg
// r11   <- y
// ymm0 <- [z0 z1 z2 z3]
// ymm1 <- [z4 z5 z6 z7]
// ymm1 <- dirty
// ymm2 <- dirty
// ymm3 <- dirty
// ymm8  <- dirty
// ymm9  <- dirty
// ymm10 <- dirty
// ymm11 <- dirty
// ymm15 <- dirty

	.p2align 4,,15
	.type inner_blender_t_8_lib4, @function
inner_blender_t_8_lib4:

	// reduction
	vhaddpd	%ymm1, %ymm0, %ymm0
	vhaddpd	%ymm5, %ymm4, %ymm4
	vhaddpd	%ymm3, %ymm2, %ymm2
	vhaddpd	%ymm7, %ymm6, %ymm6
	vperm2f128	$0x2, %ymm0, %ymm2, %ymm3
	vperm2f128	$0x2, %ymm4, %ymm6, %ymm5
	vperm2f128	$0x13, %ymm0, %ymm2, %ymm0
	vperm2f128	$0x13, %ymm4, %ymm6, %ymm4
	vaddpd	%ymm0, %ymm3, %ymm0
	vaddpd	%ymm4, %ymm5, %ymm1

	cmpl	$0, %r10d // alg
	je		.L008 // return

	cmpl	$1, %r10d // alg
	jne		.L009 // alg==-1

	// alg==1
	vmovupd		0(%r11), %ymm15
	vaddpd		%ymm0, %ymm15, %ymm0
	vmovupd		32(%r11), %ymm15
	vaddpd		%ymm1, %ymm15, %ymm1

	ret // return

.L009:

	// alg==-1
	vmovupd		0(%r11), %ymm15
	vsubpd		%ymm0, %ymm15, %ymm0
	vmovupd		32(%r11), %ymm15
	vsubpd		%ymm1, %ymm15, %ymm1

.L008: // return
	
	ret
	
	.size	inner_blender_t_8_lib4, .-inner_blender_t_8_lib4





// common inner routine with file scope
//
// store 
//
// input arguments:
// r10  <- z
// ymm0 <- [z0 z1 z2 z3]
// ymm1 <- [z4 z5 z6 z7]
//
// output arguments:
// r10  <- z
// ymm0 <- [z0 z1 z2 z3]
// ymm1 <- [z4 z5 z6 z7]

	.p2align 4,,15
	.type inner_store_8_lib4, @function
inner_store_8_lib4:
	
	vmovupd %ymm0, 0(%r10)
	vmovupd %ymm1, 32(%r10)
	
	ret

	.size	inner_store_8_lib4, .-inner_store_8_lib4





//                            rdi    rsi        rdx      rcx        r8       r9         rsp+8
// void kernel_dgemv_n_8_lib4(int k, double *A, int sda, double *x, int alg, double *y, double *z);

	.p2align 4,,15
	.globl kernel_dgemv_n_8_lib4
	.type kernel_dgemv_n_8_lib4, @function
kernel_dgemv_n_8_lib4:
	
	// prologue

	subq	$STACKSIZE, %rsp
	movq	%rbx,   (%rsp)
	movq	%rbp,  8(%rsp)
	movq	%r12, 16(%rsp)
	movq	%r13, 24(%rsp)
	movq	%r14, 32(%rsp)
	movq	%r15, 40(%rsp)

	vzeroupper


	// zero accumulation registers

	vxorpd	%ymm0, %ymm0, %ymm0
	vmovapd	%ymm0, %ymm1
	vmovapd	%ymm0, %ymm2
	vmovapd	%ymm0, %ymm3
	vmovapd	%ymm0, %ymm4
	vmovapd	%ymm0, %ymm5
	vmovapd	%ymm0, %ymm6
	vmovapd	%ymm0, %ymm7


	// call inner dgemv kernel n

	movl	%edi, %r10d // k
	movq	%rsi, %r11  // A
	movl	%edx, %r12d
	sall	$5, %r12d // 4*sda*sizeof(double)
	movslq	%r12d, %r12
	movq	%rcx, %r13  // x

	call inner_kernel_dgemv_add_n_8_lib4


	// call inner blender n

	movl	%r8d, %r10d // alg
	movq	%r9, %r11   // y

	call inner_blender_n_8_lib4


	// store

	movq	STACKSIZE + 8(%rsp), %r10 // z

	call inner_store_8_lib4


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

	.size	kernel_dgemv_n_8_lib4, .-kernel_dgemv_n_8_lib4





//                            rdi    rsi        rdx      rcx        r8       r9         rsp+8
// void kernel_dgemv_t_8_lib4(int k, double *A, int sda, double *x, int alg, double *y, double *z);

	.p2align 4,,15
	.globl kernel_dgemv_t_8_lib4
	.type kernel_dgemv_t_8_lib4, @function
kernel_dgemv_t_8_lib4:
	
	// prologue

	subq	$STACKSIZE, %rsp
	movq	%rbx,   (%rsp)
	movq	%rbp,  8(%rsp)
	movq	%r12, 16(%rsp)
	movq	%r13, 24(%rsp)
	movq	%r14, 32(%rsp)
	movq	%r15, 40(%rsp)

	vzeroupper


	// zero accumulation registers

	vxorpd	%ymm0, %ymm0, %ymm0
	vmovapd	%ymm0, %ymm1
	vmovapd	%ymm0, %ymm2
	vmovapd	%ymm0, %ymm3
	vmovapd	%ymm0, %ymm4
	vmovapd	%ymm0, %ymm5
	vmovapd	%ymm0, %ymm6
	vmovapd	%ymm0, %ymm7


	// call inner dgemv kernel n

	movl	%edi, %r10d // k
	movq	%rsi, %r11  // A
	movl	%edx, %r12d
	sall	$5, %r12d // 4*sda*sizeof(double)
	movslq	%r12d, %r12
	movq	%rcx, %r13  // x

	call inner_kernel_dgemv_add_t_8_lib4


	// call inner blender t

	movl	%r8d, %r10d // alg
	movq	%r9, %r11   // y

	call inner_blender_t_8_lib4


	// store

	movq	STACKSIZE +  8(%rsp), %r10 // z 

	call inner_store_8_lib4


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

	.size	kernel_dgemv_t_8_lib4, .-kernel_dgemv_t_8_lib4





	// read-only data
	.section	.rodata.cst32,"aM",@progbits,32
#if 1
	.align 32
.LC00: // { -1 -1 -1 1 }
	.quad	-1
	.quad	-1
	.quad	-1
	.quad	1
	.align 32
.LC01: // { -1 -1 -1 -1 }
	.quad	-1
	.quad	-1
	.quad	-1
	.quad	-1
#endif
	.align 32
.LC02: // { 3.5 2.5 1.5 0.5 }
	.long	0
	.long	1071644672
	.long	0
	.long	1073217536
	.long	0
	.long	1074003968
	.long	0
	.long	1074528256
	.align 32
.LC03: // { 7.5 6.5 5.5 4.5 }
	.long	0
	.long	1074921472
	.long	0
	.long	1075183616
	.long	0
	.long	1075445760
	.long	0
	.long	1075707904
	.align 16
.LC04: // { 1 }
	.long	0
	.long	1072693248
	.long	0
	.long	0



	.section	.note.GNU-stack,"",@progbits

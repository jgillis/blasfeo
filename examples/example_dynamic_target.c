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
 * TARGET=DYNAMIC: show the target selected at load time and check that the
 * matrix layout seen through BLASFEO_DMATEL (runtime panel size D_PS) is the
 * one of the selected target, against a plain column-major computation.
 */

#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include <blasfeo.h>



int main()
	{

	int n = 13;
	int ii, jj, kk;

	printf("\ntarget %s, D_PS %d, S_PS %d\n\n", blasfeo_dynamic_target(), D_PS, S_PS);

	double *A = malloc(n*n*sizeof(double));
	double *C_ref = malloc(n*n*sizeof(double));
	double *L = malloc(n*n*sizeof(double));
	for(jj=0; jj<n; jj++)
		for(ii=0; ii<n; ii++)
			A[ii+n*jj] = sin(1.0+ii+3*jj);

	// C_ref = A * A^T + n * I
	for(jj=0; jj<n; jj++)
		for(ii=0; ii<n; ii++)
			{
			C_ref[ii+n*jj] = ii==jj ? n : 0.0;
			for(kk=0; kk<n; kk++)
				C_ref[ii+n*jj] += A[ii+n*kk]*A[jj+n*kk];
			}

	struct blasfeo_dmat sA, sC, sL;
	blasfeo_allocate_dmat(n, n, &sA);
	blasfeo_allocate_dmat(n, n, &sC);
	blasfeo_allocate_dmat(n, n, &sL);

	// write through the layout macro
	for(jj=0; jj<n; jj++)
		for(ii=0; ii<n; ii++)
			BLASFEO_DMATEL(&sA, ii, jj) = A[ii+n*jj];

	blasfeo_dgese(n, n, 0.0, &sC, 0, 0);
	blasfeo_ddiare(n, (double) n, &sC, 0, 0);
	blasfeo_dgemm_nt(n, n, n, 1.0, &sA, 0, 0, &sA, 0, 0, 1.0, &sC, 0, 0, &sC, 0, 0);

	// read through the layout macro
	double err_gemm = 0.0;
	for(jj=0; jj<n; jj++)
		for(ii=0; ii<n; ii++)
			err_gemm = fmax(err_gemm, fabs(BLASFEO_DMATEL(&sC, ii, jj)-C_ref[ii+n*jj]));
	printf("dgemm_nt  max error %e\n", err_gemm);

	// L * L^T = C_ref
	blasfeo_dpotrf_l(n, &sC, 0, 0, &sL, 0, 0);
	blasfeo_unpack_dmat(n, n, &sL, 0, 0, L, n);
	double err_potrf = 0.0;
	for(jj=0; jj<n; jj++)
		for(ii=jj; ii<n; ii++)
			{
			double tmp = 0.0;
			for(kk=0; kk<=jj; kk++)
				tmp += L[ii+n*kk]*L[jj+n*kk];
			err_potrf = fmax(err_potrf, fabs(tmp-C_ref[ii+n*jj]));
			}
	printf("dpotrf_l  max error %e\n\n", err_potrf);

	blasfeo_free_dmat(&sA);
	blasfeo_free_dmat(&sC);
	blasfeo_free_dmat(&sL);
	free(A);
	free(C_ref);
	free(L);

	return err_gemm<1e-10 && err_potrf<1e-10 ? 0 : 1;

	}

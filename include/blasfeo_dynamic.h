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

// TARGET=DYNAMIC: the target, and with it the panel sizes, is selected at load
// time; such a library (blasfeo-dynamic) is not ABI compatible with blasfeo

#ifndef BLASFEO_DYNAMIC_H_
#define BLASFEO_DYNAMIC_H_

#ifdef __cplusplus
extern "C" {
#endif

// data imported from a Windows DLL needs dllimport (MSVC; MinGW also auto-imports)
#if defined(_WIN32) && defined(BLASFEO_DYNAMIC_DLL) && !defined(BLASFEO_DYNAMIC_BUILD)
#define BLASFEO_DYNAMIC_DATA __declspec(dllimport)
#else
#define BLASFEO_DYNAMIC_DATA
#endif

// panel sizes of the selected target (D_PS, S_PS)
BLASFEO_DYNAMIC_DATA extern int blasfeo_d_ps;
BLASFEO_DYNAMIC_DATA extern int blasfeo_s_ps;

// name of the selected target, e.g. "X64_INTEL_HASWELL"
const char *blasfeo_dynamic_target(void);

#ifdef __cplusplus
}
#endif

#endif  // BLASFEO_DYNAMIC_H_

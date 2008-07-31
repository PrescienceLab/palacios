/*BEGIN_LEGAL 
Intel Open Source License 

Copyright (c) 2002-2007 Intel Corporation 
All rights reserved. 
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.  Redistributions
in binary form must reproduce the above copyright notice, this list of
conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.  Neither the name of
the Intel Corporation nor the names of its contributors may be used to
endorse or promote products derived from this software without
specific prior written permission.
 
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE INTEL OR
ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
END_LEGAL */
/// @file xed-operand-enum.h
/// @author Mark Charney <mark.charney@intel.com>

// This file was automatically generated.
// Do not edit this file.

#if !defined(_XED_OPERAND_ENUM_H_)
# define _XED_OPERAND_ENUM_H_
#include "xed-common-hdrs.h"
typedef enum {
  XED_OPERAND_INVALID,
  XED_OPERAND_AGEN,
  XED_OPERAND_AMODE,
  XED_OPERAND_ASZ,
  XED_OPERAND_BASE0,
  XED_OPERAND_BASE1,
  XED_OPERAND_BRDISP_WIDTH,
  XED_OPERAND_BRDISP0,
  XED_OPERAND_BRDISP1,
  XED_OPERAND_DEFAULT_SEG,
  XED_OPERAND_DF64,
  XED_OPERAND_DISP_WIDTH,
  XED_OPERAND_DISP0,
  XED_OPERAND_DISP1,
  XED_OPERAND_DISP2,
  XED_OPERAND_DISP3,
  XED_OPERAND_EASZ,
  XED_OPERAND_ENCODER_PREFERRED,
  XED_OPERAND_EOSZ,
  XED_OPERAND_ERROR,
  XED_OPERAND_HINT_TAKEN,
  XED_OPERAND_HINT_NOT_TAKEN,
  XED_OPERAND_ICLASS,
  XED_OPERAND_IMM_WIDTH,
  XED_OPERAND_IMM0,
  XED_OPERAND_IMM0SIGNED,
  XED_OPERAND_IMM1,
  XED_OPERAND_INDEX,
  XED_OPERAND_LOCK,
  XED_OPERAND_LOCKABLE,
  XED_OPERAND_MEM_WIDTH,
  XED_OPERAND_MEM0,
  XED_OPERAND_MEM1,
  XED_OPERAND_MOD,
  XED_OPERAND_MODE,
  XED_OPERAND_MODRM,
  XED_OPERAND_NOREX,
  XED_OPERAND_OSZ,
  XED_OPERAND_OUTREG,
  XED_OPERAND_PTR,
  XED_OPERAND_REFINING,
  XED_OPERAND_REG,
  XED_OPERAND_REG0,
  XED_OPERAND_REG1,
  XED_OPERAND_REG2,
  XED_OPERAND_REG3,
  XED_OPERAND_REG4,
  XED_OPERAND_REG5,
  XED_OPERAND_REG6,
  XED_OPERAND_REG7,
  XED_OPERAND_REG8,
  XED_OPERAND_REG9,
  XED_OPERAND_REG10,
  XED_OPERAND_REG11,
  XED_OPERAND_REG12,
  XED_OPERAND_REG13,
  XED_OPERAND_REG14,
  XED_OPERAND_REG15,
  XED_OPERAND_RELBR,
  XED_OPERAND_REP,
  XED_OPERAND_REP_ABLE,
  XED_OPERAND_REX,
  XED_OPERAND_REXB,
  XED_OPERAND_REXR,
  XED_OPERAND_REXW,
  XED_OPERAND_REXX,
  XED_OPERAND_RM,
  XED_OPERAND_SCALE,
  XED_OPERAND_SEG_OVD,
  XED_OPERAND_SEG0,
  XED_OPERAND_SEG1,
  XED_OPERAND_SIB,
  XED_OPERAND_SIBBASE,
  XED_OPERAND_SIBINDEX,
  XED_OPERAND_SIBSCALE,
  XED_OPERAND_SMODE,
  XED_OPERAND_UIMM00,
  XED_OPERAND_UIMM1,
  XED_OPERAND_UIMM01,
  XED_OPERAND_UIMM02,
  XED_OPERAND_UIMM03,
  XED_OPERAND_USING_DEFAULT_SEGMENT0,
  XED_OPERAND_USING_DEFAULT_SEGMENT1,
  XED_OPERAND_LAST
} xed_operand_enum_t;

XED_DLL_EXPORT xed_operand_enum_t
str2xed_operand_enum_t(const char* s);
XED_DLL_EXPORT const char*
xed_operand_enum_t2str(const xed_operand_enum_t p);

#endif

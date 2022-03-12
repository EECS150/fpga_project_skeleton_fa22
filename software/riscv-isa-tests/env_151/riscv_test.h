// See LICENSE for license details.

#ifndef _ENV_PHYSICAL_SINGLE_CORE_H
#define _ENV_PHYSICAL_SINGLE_CORE_H

#include "encoding.h"

//-----------------------------------------------------------------------
// Begin Macro
//-----------------------------------------------------------------------

#define RVTEST_RV64U                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV64UF                                                   \
  .macro init;                                                          \
  .endm

#define RVTEST_RV32U                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV32UF                                                   \
  .macro init;                                                          \
  .endm

#define RVTEST_RV64M                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV64S                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV32M                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_RV32S                                                    \
  .macro init;                                                          \
  .endm

#define RVTEST_CODE_BEGIN                                               \
        .section .text.init;                                            \
        .align  6;                                                      \
        .globl _start;                                                  \
_start:                                                                 \
        /* reset vector */                                              \
        j reset_vector;                                                 \
        .align 2;                                                       \
reset_vector:                                                           \
        csrwi 0x51e, 0;                                                 \
        li TESTNUM, 0;                                                  \
        init                                                            \

//-----------------------------------------------------------------------
// End Macro
//-----------------------------------------------------------------------

#define RVTEST_CODE_END                                                 \
        unimp

//-----------------------------------------------------------------------
// Pass/Fail Macro
//-----------------------------------------------------------------------

#define RVTEST_PASS                                                     \
        li TESTNUM, 1;                                                  \
        csrw 0x51e, TESTNUM;                                            \
p:      j p

#define TESTNUM gp
#define RVTEST_FAIL                                                     \
        sll TESTNUM, TESTNUM, 1;                                        \
        or TESTNUM, TESTNUM, 1;                                         \
        csrw 0x51e, TESTNUM;                                            \
f:      j f

//-----------------------------------------------------------------------
// Data Section Macro
//-----------------------------------------------------------------------

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN                                               \
        EXTRA_DATA                                                      \
        .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif

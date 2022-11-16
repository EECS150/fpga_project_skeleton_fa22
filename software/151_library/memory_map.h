#include "types.h"

#define csr_tohost(csr_val) { \
    asm volatile ("csrw 0x51e,%[v]" :: [v]"r"(csr_val)); \
}

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))
#define BRANCH_INSTRUCTION_COUNTER (*((volatile uint32_t*)0x8000001c))
#define BRANCH_PREDICTION_CORRECT_COUNTER (*((volatile uint32_t*)0x80000020))

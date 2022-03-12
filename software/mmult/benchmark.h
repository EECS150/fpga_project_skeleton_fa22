#ifndef BENCHMARK_H_
#define BENCHMARK_H_

#include "types.h"

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))

void run_and_time(uint32_t (*f)());
#endif

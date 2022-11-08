#include "types.h"
#include "memory_map.h"

// Source: one of the bmark tests from ASIC lab
// John C. Wright
// johnwright@eecs.berkeley.edu
// Do some random stuff to test EECS151/251A rv32ui processors

#define PRBS  10
#define CONST 1011556

#define NUMELTS (1<<PRBS)-1
#define MASK (1<<(PRBS-1))-1

unsigned int assert_equals(unsigned int a, unsigned int b);
int x[NUMELTS];

void main() {
  csr_tohost(0);
  x[0] = 1;
  int i;
  for(i = 1; i < NUMELTS; i++) {
    x[i] = ((x[i-1] >> 1) & MASK) | (((x[i-1] & 1) ^ ((x[i-1] & 2) >> 1)) << (PRBS-1));
  }

  int y = 0;
  for(i = 0; i < NUMELTS; i++) {
    y += x[i] + x[NUMELTS-1-i];
  }

  if(assert_equals(y, CONST)) {
    csr_tohost(1);
  } else {
    csr_tohost(2);
  }

  // spin
  for( ; ; ) {
    asm volatile ("nop");
  }
}

unsigned int assert_equals(unsigned int a, unsigned int b) {
  return (a == b);
}

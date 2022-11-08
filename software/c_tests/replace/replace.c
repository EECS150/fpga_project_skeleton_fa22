#include "types.h"
#include "memory_map.h"

// Source: one of the bmark tests from ASIC lab
// John C. Wright
// johnwright@eecs.berkeley.edu
// Do some random stuff to test EECS151/251A rv32ui processors

#define NUMELTS 64
#define CONST   2080

#define MASK (1<<31)-1

unsigned int assert_equals(unsigned int a, unsigned int b);
int x[NUMELTS];
int y[NUMELTS];

void main() {
  csr_tohost(0);
  int i;
  int j;
  for(i = 0; i < NUMELTS; i++) {
    x[i] = i + 1;
  }

  for(i = 0; i < NUMELTS; i+=4) {
    y[i] = 0;
    for(j=0; j < i+1; j++) {
      y[i] = y[i] + x[j];
    }
  }

  for(i = 1; i < NUMELTS; i+=4) {
    y[i] = 0;
    for(j=0; j < i+1; j++) {
      y[i] = y[i] + x[j];
    }
  }

  for(i = 2; i < NUMELTS; i+=4) {
    y[i] = 0;
    for(j=0; j < i+1; j++) {
      y[i] = y[i] + x[j];
    }
  }

  for(i = 3; i < NUMELTS; i+=4) {
    y[i] = 0;
    for(j=0; j < i+1; j++) {
      y[i] = y[i] + x[j];
    }
  }

  if(assert_equals(y[NUMELTS-1], CONST)) {
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

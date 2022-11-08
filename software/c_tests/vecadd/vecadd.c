#include "types.h"
#include "ascii.h"
#include "uart.h"
#include "memory_map.h"

#define BUF_LEN 128

#define DIM 64
#define SIZE 1024
static int32_t A[SIZE] = {0}; // 3x1024x32b 16384x32b
static int32_t B[SIZE] = {0};
static int32_t C[SIZE] = {0};

typedef void (*entry_t)(void);

int main(int argc, char**argv) {
  csr_tohost(0);
  int8_t buffer[BUF_LEN];

  int i, j;
  int chksum = 0;

  for (i = 0; i < SIZE; i++) {
    A[i] = 1;
    B[i] = i;
  }

  for (i = 0; i < SIZE; i++) {
    C[i] = A[i] + B[i];
  }

  for (i = 0; i < SIZE; i++) {
    chksum += C[i];
  }

  csr_tohost(0);

  if (chksum == 0x80200) {
    // pass
    csr_tohost(1);
  } else {
    // fail code 2
    csr_tohost(2);
  }

  // spin
  for( ; ; ) {
    asm volatile ("nop");
  }
}

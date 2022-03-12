#include "types.h"
#include "ascii.h"
#include "uart.h"
#include "memory_map.h"

#define BUF_LEN 128

#define SIZE 16

static int8_t array0[SIZE] = {0};
static int8_t array1[SIZE] = {0};

typedef void (*entry_t)(void);

// This simple test loops data from DMem to DDR and back
int main(int argc, char**argv) {
  int8_t buffer[BUF_LEN];
  int32_t len = SIZE;
  int32_t i;

  for (i = 0; i < len; i++) {
    array1[i] = i;
  }

  // Copy data from array1 from DMem to DDR at address 0x40_0000
  DMA_DIR = 1;
  DMA_DST_ADDR = 0x900000;
  // shift right by 2 because the DMA uses word-level addressing to access DMem
  DMA_SRC_ADDR = (uint32_t)array1 >> 2;
  // shift right by 2 because we're sending 8b data on 32b data bus
  DMA_LEN = len >> 2;
  DMA_START = 1;
  while (!DMA_DONE);

  // Copy data from DDR at address 0x40_0000 to array0 from DMem
  DMA_DIR = 0;
  DMA_SRC_ADDR = 0x900000;
  // shift right by 2 because the DMA uses word-level addressing to access DMem
  DMA_DST_ADDR = (uint32_t)array0 >> 2;
  // shift right by 2 because we're sending 8b data on 32b data bus
  DMA_LEN = len >> 2;
  DMA_START = 1;
  while (!DMA_DONE);

  uint32_t num_mismatches = 0;
  // Make sure that the two arrays match!
  for (i = 0; i < len; i++) {
    uwrite_int8s("\r\n>>> At ");
    uwrite_int8s(uint8_to_ascii_hex(i, buffer, BUF_LEN));
    uwrite_int8s("\r\narray0 ");
    uwrite_int8s(uint8_to_ascii_hex(array0[i], buffer, BUF_LEN));
    uwrite_int8s("\r\narray1 ");
    uwrite_int8s(uint8_to_ascii_hex(array1[i], buffer, BUF_LEN));

    if (array0[i] != array1[i]) {
      num_mismatches += 1;
    }
  }

  if (num_mismatches == 0)
    uwrite_int8s("\r\nPassed!\r\n");
  else {
    uwrite_int8s("\r\nFailed! Num. mismatches ");
    uwrite_int8s(uint8_to_ascii_hex(num_mismatches, buffer, BUF_LEN));
    uwrite_int8s("\r\n");
  }

  // go back to the bios - using this function causes a jr to the addr,
  // the compiler "jals" otherwise and then cannot set PC[31:28]
  uint32_t bios = ascii_hex_to_uint32("40000000");
  entry_t start = (entry_t) (bios);
  start();
  return 0;
}

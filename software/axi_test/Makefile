# Master Makefile dependencies
TARGET := axi_test
INCLUDE_LIB := true
GCC_OPTS += -O2

include ../Makefile.gcc.in

run: axi_test.elf
	../../scripts/hex_to_serial axi_test.mif 30000000


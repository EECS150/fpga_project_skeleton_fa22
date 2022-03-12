SHELL := $(shell which bash) -o pipefail
TESTS := $(notdir $(shell find riscv-tests/isa/rv32ui -type f -name "*.S"))
TESTS_HEX := $(subst .S,.hex,$(TESTS))
GCC_OPTS := -march=rv32i -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -T env_151/link.ld -Wl,--build-id=none

RISCV_PACKAGE := riscv64-linux-gnu
RISCV_DEFAULT := riscv64-unknown-elf
RISCV_DEFAULT_PRESENT := $(shell command -v $(RISCV_DEFAULT)-gcc 2> /dev/null)

ifdef RISCV_DEFAULT_PRESENT
    RISCV := $(RISCV_DEFAULT)
else
    RISCV := $(RISCV_PACKAGE)
endif

all: $(TESTS_HEX)

%.hex: riscv-tests/isa/rv32ui/%.S
	$(RISCV)-gcc $(GCC_OPTS) -Ienv_151 -Iriscv-tests/env -Iriscv-tests/isa/macros/scalar $^ -o $(basename $(notdir $^)).elf
	$(RISCV)-objdump -D -Mnumeric $(basename $(notdir $^)).elf > $(basename $@).dump
	$(RISCV)-objcopy $(basename $@).elf -O binary $(basename $@).bin
	$(RISCV)-bin2hex -w 32 $(basename $@).bin $(basename $@).mif

clean:
	rm -f *.elf *.bin *.mif *.dump

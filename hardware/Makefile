SHELL                   := $(shell which bash) -o pipefail
ABS_TOP                 := $(subst /cygdrive/c/,C:/,$(shell pwd))
SCRIPTS                 := $(ABS_TOP)/scripts
VIVADO                  ?= vivado
VIVADO_OPTS             ?= -nolog -nojournal -mode batch
FPGA_PART               ?= xc7z020clg400-1
RTL                     += $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/src -type f -name "*.v"))
CONSTRAINTS             += $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/src -type f -name "*.xdc"))
TOP                     ?= z1top
VCS                     := vcs -full64
VCS_OPTS                := -notice -line +lint=all,noVCDE,noNS,noSVA-UA -sverilog -timescale=1ns/10ps -debug +define+ABS_TOP=$(ABS_TOP) +incdir+$(ABS_TOP)/src/riscv_core
SIM_RTL                 := $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/sim -type f -name "*.v"))
SIM_MODELS              := $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/sim_models -type f -name "*.v"))
IVERILOG                := iverilog
IVERILOG_OPTS           := -Ttyp -D IVERILOG=1 -g2012 -gassertions -Wall -Wno-timescale -D ABS_TOP=$(ABS_TOP) -I $(ABS_TOP)/src/riscv_core -I $(ABS_TOP)/sim
VVP                     := vvp
ISA_TESTS               := $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/../software/riscv-isa-tests -type f -name "*.hex"))
ISA_TESTS_FILES         := $(notdir $(ISA_TESTS))
ISA_TESTS_FST           := $(addprefix sim/isa/,$(subst .hex,.fst,$(ISA_TESTS_FILES)))
C_TESTS                 := $(subst /cygdrive/c/,C:/,$(shell find $(ABS_TOP)/../software/c_tests -type f -name "*.c"))
C_TESTS_FILES           := $(notdir $(C_TESTS))
C_TESTS_FST             := $(addprefix sim/c_tests/,$(subst .c,.fst,$(C_TESTS_FILES)))

sim/%.tb: sim/%.v $(RTL) $(SIM_MODELS)
	cd sim && $(VCS) $(VCS_OPTS) -o $*.tb $(RTL) $(SIM_MODELS) $*.v -top $* -top glbl

sim/%.vpd: sim/%.tb
	cd sim && ./$*.tb +verbose=1 +vpdfile+$*.vpd |& tee $*.log

sim/%.tbi: sim/%.v $(RTL)
	cd sim && $(IVERILOG) $(IVERILOG_OPTS) -o $*.tbi $*.v $(RTL) $(SIM_MODELS)

sim/%.fst: sim/%.tbi
	cd sim && $(VVP) $*.tbi -fst |& tee $*.log

# ISA Tests
sim/isa/isa_tb.tbi: sim/isa_tb.v $(RTL) $(SIM_MODELS)
	mkdir -p sim/isa
	cd sim/isa && $(IVERILOG) $(IVERILOG_OPTS) -o isa_tb.tbi ../isa_tb.v $(RTL) $(SIM_MODELS)

sim/isa/%.fst: sim/isa/isa_tb.tbi $(ABS_TOP)/../software/riscv-isa-tests/%.hex
	cd sim/isa && $(VVP) isa_tb.tbi -fst +hex_file=$(word 2,$^) +test_name=$(basename $(notdir $(word 2,$^))) |& tee $(basename $(notdir $(word 2,$^))).log

isa-tests: $(ISA_TESTS_FST)

# C Tests
sim/c_tests/c_tests_tb.tbi: sim/c_tests_tb.v $(RTL) $(SIM_MODELS)
	mkdir -p sim/c_tests
	cd sim/c_tests && $(IVERILOG) $(IVERILOG_OPTS) -o c_tests_tb.tbi ../c_tests_tb.v $(RTL) $(SIM_MODELS)

sim/c_tests/%.fst: sim/c_tests/c_tests_tb.tbi $(ABS_TOP)/../software/c_tests/%
	cd sim/c_tests && $(VVP) c_tests_tb.tbi -fst +hex_file=$(word 2,$^)/$*.hex +test_name=$(basename $(notdir $(word 2,$^))) |& tee $(basename $(notdir $(word 2,$^))).log

c-tests: $(C_TESTS_FST)

build/target.tcl: $(RTL) $(CONSTRAINTS)
	mkdir -p build
	truncate -s 0 $@
	echo "set ABS_TOP                        $(ABS_TOP)"    >> $@
	echo "set TOP                            $(TOP)"    >> $@
	echo "set FPGA_PART                      $(FPGA_PART)"  >> $@
	echo "set_param general.maxThreads       4"    >> $@
	echo "set_param general.maxBackupLogs    0"    >> $@
	echo -n "set RTL { " >> $@
	FLIST="$(RTL)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@
	echo -n "set CONSTRAINTS { " >> $@
	FLIST="$(CONSTRAINTS)"; for f in $$FLIST; do echo -n "$$f " ; done >> $@
	echo "}" >> $@

setup: build/target.tcl

elaborate: build/target.tcl $(SCRIPTS)/elaborate.tcl
	mkdir -p ./build
	cd ./build && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/elaborate.tcl |& tee elaborate.log

build/synth/$(TOP).dcp: build/target.tcl $(SCRIPTS)/synth.tcl
	mkdir -p ./build/synth/
	cd ./build/synth/ && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/synth.tcl |& tee synth.log

synth: build/synth/$(TOP).dcp

build/impl/$(TOP).bit: build/synth/$(TOP).dcp $(SCRIPTS)/impl.tcl
	mkdir -p ./build/impl/
	cd ./build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/impl.tcl |& tee impl.log

impl: build/impl/$(TOP).bit
all: build/impl/$(TOP).bit

program: build/impl/$(TOP).bit $(SCRIPTS)/program.tcl
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/program.tcl

program-force:
	cd build/impl && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/program.tcl

vivado: build
	cd build && nohup $(VIVADO) </dev/null >/dev/null 2>&1 &

lint:
	verilator -DABS_TOP=$(ABS_TOP) --lint-only --top-module $(TOP) $(RTL) -I$(ABS_TOP)/src/riscv_core $(ABS_TOP)/stubs/PLLE2_ADV.v $(ABS_TOP)/sim_models/BUFG.v

sim_build/compile_simlib/synopsys_sim.setup:
	mkdir -p sim_build/compile_simlib
	cd build/sim_build/compile_simlib && $(VIVADO) $(VIVADO_OPTS) -source $(SCRIPTS)/compile_simlib.tcl

compile_simlib: sim_build/compile_simlib/synopsys_sim.setup

screen:
	screen /dev/ttyUSB0 115200

clean-sim:
	rm -rf *.daidir sim/output.txt \
	sim/*.tb sim/*.daidir sim/csrc \
	sim/ucli.key sim/*.vpd sim/*.vcd \
	sim/*.tbi sim/*.fst sim/*.jou sim/*.log sim/*.out \
	sim/isa sim/c_tests

clean-build:
	rm -rf ./build

.PHONY: setup synth impl program program-force vivado all clean-build clean-sim %.tb
.PRECIOUS: sim/%.tb sim/%.tbi sim/%.fst sim/%.vpd

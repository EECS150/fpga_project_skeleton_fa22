
# Some available commands

## Simulation

### IVERILOG

make iverilog-sim tb={testbench_name}

which testbench_name = {
  Riscv151_testbench,
  echo_testbench,
  c_testbench,
  bios_testbench,
  software_testbench,
  assembly_testbench }

isa_testbench needs an extra argument "test" to select which ISA test to simulate

make iverilog-sim tb=isa_testbench test=add
- Run the ISA testbench with test "add" from the RISCV test suite

make iverilog-sim tb=isa_testbench test=add
- Run all the 38 tests from the RISCV test suite 

make wave tb={testbench_name}
- Run the simulation, and open the waveform with GTKWave

make wave tb=isa_testbench test=add
- Run the ISA testbench with test "add", and open the wavefrom with GTKWave

software_testbench needs an extra argument "sw" to select which software test
(from software/) to simulate

make iverilog-sim tb=software_testbench sw=strcmp
make iverilog-sim tb=software_testbench sw=fib
make iverilog-sim tb=software_testbench sw=cachetest
make iverilog-sim tb=software_testbench sw=replace
make iverilog-sim tb=software_testbench sw=sum
make iverilog-sim tb=software_testbench sw=vecadd

Simulate xcel accelerator (no Riscv151)
make iverilog-sim tb=xcel_testbench (compute unit + memory unit)
make iverilog-sim tb=conv3D_testbench (only compute unit)

### VIVADO XSIM

make sim tb={testbench_name}
make sim tb=isa_testbench test=add
make sim tb=isa_testbench test=all

## Bitstream Generation

make build-project
make write-bitstream
make write-bitstream proj=z1top_axi clk=20

## Program FPGA

make program-fpga bs=bitstream_files/z1top.bit
make program-fpga bs=bitstream_files/z1top_axi.bit

# Initiaze the ARM cores (Zynq Processing System)
make init-arm


# Testing Framework

## Simulation

### Regular Testbenches

#### iverilog
```bash
make sim/cpu_tb.fst
# logfile
cat sim/cpu_tb.log
# waveform
gtkwave sim/cpu_tb.fst &
```

#### VCS
```bash
make sim/cpu_tb.vpd
# logfile
cat sim/cpu_tb.log
# waveform
dve -vpd sim/cpu_tb.vpd &
```

### ISA Tests
```bash
make isa-tests
gtkwave sim/isa/rv32ui-p-add.fst &
```

- Clean simulation outputs: `make clean-sim`
- Forcefully re-run a testbench: `make -B sim/cpu_tb.fst`

## CAD Flow
- Lint RTL with verilator: `make lint`
- Open Vivado GUI: `make vivado`
- Elaborate and open circuit in GUI: `make elaborate`
- Synthesis: `make synth`
    - Log file: `build/synth/synth.log`
- Place, Route, Bitstream Generation (Implementation): `make impl`
    - Log file: `build/impl/impl.log`
- Program FPGA: `make program`
- Force program FPGA (don't rebuild bitstream if RTL changed): `make program-force`
- Clean CAD flow outputs: `make clean-build`

## Runtime
- Run screen to open UART connection: `make screen`
    - To exit screen: Ctrl-A Shift-K (then press 'y')

## Testing Your CPU
The design specified for this project is a complex system and debugging can be very difficult without tests that increase visibility of certain areas of the design.
In assigning partial credit at the end for incomplete projects, we will look at testing as an indicator of progress.
A reasonable order in which to complete your testing is as follows:

1. Test that your modules work in isolation via Verilog testbenches that you write yourself
1. Test that your CPU pipeline works with `sim/cpu_tb.v`
1. Test the entire CPU one instruction at a time with hand-written assembly using `sim/asm_tb.v`
1. Run the `riscv-tests` ISA test suite (`make isa-tests`)
1. Some extra tests with other software C program, such as the `c_tests` and `uart_parse`. They could help reveal more bugs -- see `c_tests_tb.v` and `uart_parse_tb.v`
1. Test the CPU's memory mapped I/O --- see `echo_tb.v`
1. Test the CPU's memory mapped I/O with BIOS software program --- see `bios_tb.v`

### Unit Tests
You should write unit tests for the isolated components of your CPU such as the register file, decoder, and ALU in `hardware/sim`.
The tests should contain assertions and check correct behavior under several common and extreme conditions.

Run them just like you did in the labs. `make sim/tb.fst` (iverilog) or `make sim/tb.vpd` (VCS).
View the waveforms with `gtkwave sim/tb.fst &` or `dve -vpd sim/tb.vpd &`.

### CPU Test
Once you are confident that the individual components of your processor are working in isolation, you will want to test the entire processor as a whole.
The provided `sim/cpu_tb.v` tests all the RV32I instructions.
Run it as usual.

To pass this testbench, you should have a working CPU implementation that can decode and execute all the instructions in the spec, including the CSR instructions.
Several basic hazard cases are also tested.

The testbench does not work with any software code as in the following sections, but rather it manually initializes the instructions and data in the memory blocks as well as the register file content for each test.
The testbench does not cover reading from BIOS memory nor memory mapped IO. You will need to complete these components before moving on with other testbenches.

### Assembly Tests
Once the `cpu_tb` passes, you should write more assembly tests by hand to aggresively test hazards, branches, and jumps.
You should write your assembly tests in `software/asm/start.s` with the corresponding testbench in `hardware/sim/asm_tb.v`.

Initially, and if you change `start.s` you need to **run `make`** in `software/asm` before running `make sim/asm_tb.vpd`.
To force simulation to run even if your RTL hasn't changed, you can use the -B flag, like `make -B sim/asm_tb.vpd`.
This applies to **all** software testbenches.

`start.s` contains assembly that's compiled and loaded into the BIOS RAM by the testbench.

```asm
_start:

# Test ADD
li x10, 100         # Load argument 1 (rs1)
li x11, 200         # Load argument 2 (rs2)
add x1, x10, x11    # Execute the instruction being tested
li x20, 1           # Set the flag register to stop execution and inspect the result register
                    # Now we check that x1 contains 300 in the testbench

Done: j Done
```

The `asm_tb` toggles the clock one cycle at time and waits for register `x20` to be written with a particular value (in the above example: 1).
Once `x20` contains 1, the testbench inspects the value in `x1` and checks it is 300, which indicates your processor correctly executed the add instruction.

If the testbench times out it means `x20` never became 1, so the processor got stuck somewhere or `x20` was written with another value.

You should add your own tests to verify that your processor can execute different instructions correctly.
Modify the file `start.s` to add your assembly code, modify `asm_tb.v` to add your checks, and then rerun the RTL simulation.

<a name="riscv-isa-tests"></a>
### RISC-V ISA Tests
You will need the CSR instructions to work before you can use this test suite, and you should have confidence in your hand-written assembly tests.

To run the ISA tests, first pull the latest skeleton changes:
``` shell
git pull skeleton master
git submodule update --init --recursive
```

The rv32i tests will be cloned into `software/riscv-isa-tests/riscv-tests/isa/rv32ui/`.

To compile the tests run:
```shell
cd software/riscv-isa-tests && make
```

To run the tests run:
```shell
cd hardware
make isa-tests  # to run all ISA tests
make sim/isa/lw.fst  # to run a specific test
grep -r -i "failed" sim/isa/*.log  # to check for failures
grep -r -i "passed" sim/isa/*.log  # to check for passing tests
grep -r -i "timeout" sim/isa/*.log  # to check for tests that timed out
```

The simulation log details which tests passed and failed and the number of clock cycles elapsed.
If you're failing a test, debug using the test assembly file in `software/riscv-isa-tests/riscv-tests/isa/rv32ui` or the generated assembly dump.

The assembly dump files are extremely helpful in debugging at this stage.
If you look into a particular dump file of a test (e.g., `add.dump`), it contains several subtests in series.
The CSR output from the simulation indicates which subtest is failing to help you narrow down where the problem is, and you can start debugging from there.

The `RESET_PC` parameter is used in `isa_tb` to start the test in the IMEM instead of the BIOS.
Make sure you have used it in `riscv_core/cpu.v`.

The `fence_i` test may fail, and that is **OK**.

### RISC-V Programs

#### Compiler Toolchain
Here's some background about the the toolchain that's used to compile RISC-V binaries.
The GCC RISC-V cross-compiler toolchain is avaialble on any of the c111 machines.

The most relevant programs in the toolchain are:
- `riscv64-unknown-elf-gcc`: GCC for RISC-V, compiles C code to RISC-V binaries.
- `riscv64-unknown-elf-as`: RISC-V assembler, compiles assembly code to RISC-V binaries.
- `riscv64-unknown-elf-objdump`: Dumps RISC-V binaries as readable assembly code.

Look at the `software/echo` folder for an example of a C program.

There are several files:

- `start.s`: This is an assembly file that contains the start of the program.
      It initialises the stack pointer (`sp`) then jumps to the `main` label.
      Edit this file to move the top of the stack.
      Typically your stack pointer is set to the top of the data memory address space, so that the stack has enough room to grow downwards.
- `echo.ld`: This linker script sets the base address of the program.
      For Checkpoint 1, this address should be in the format `0x1000xxxx` (indicating the base of IMEM/DMEM).
      The .text segment offset is typically set to the base of the instruction memory address space.
- `echo.elf`: Binary produced after running `make`.
- `echo.dump`: Assembly dump of the binary.

#### C Tests
Next, you will test your processor with some small RISC-V C programs.
We use the RISC-V software toolchain to compile a program to a hex file that is used to initialize the `imem` and `dmem`.

The C tests are in `software/c_tests`.
You should go into each folder, understand what the program is trying to do, and **run `make`** to generate a `.hex` file.
The available tests include: `strcmp`, `vecadd`, `fib`, `sum`, `replace`, `cachetest`.

To run the tests:
```shell
cd hardware
make c-tests  # run all C tests
make sim/c_tests/fib.fst  # run the fib C test
```

These tests could help reveal more hazard bugs in your implementation.
`strcmp` is particularly important since it is frequently used in the BIOS program.

The tests use CSR instruction to indicate if they are passed (e.g., write '1' to the CSR register if passed).
Following that practice, you can also **write your custom C programs** to further test your CPU.

As an additional tip for debugging, try changing the compiler optimization flag in the `Makefile` of each software test (e.g., `-O2` to `-O1` or `-O0`) and see if your processor still passes the test.
Different compiler settings generate different sequences of assembly instructions, and some might expose subtle hazard bugs yet to be covered by your implementation.

### Echo Program Test
You should have your UART modules integrated with the CPU before running this test.
The test verifies if your CPU is able to: check the UART status, read a character from UART Receiver, and write a character to UART Transmitter.

Take a look at the software code `software/echo/echo.c` to see what it does.
The testbench loads the hex file compiled from the software code, and load it to the BIOS memory in a similar manner to the `asm` test and `riscv-isa-tests`.

To compile echo:
```shell
cd software/echo && make
```

To run the test:
```shell
cd hardware
make sim/echo_tb.fst  # or .vpd
```

The testbench acts like a host and sends multiple characters via the serial line, then waits until it receives all the characters back.
In some sense, it is similar to the echo test in Lab 5, however, the UART modules are controlled by the software program (`software/echo/echo.c`) running on your RISC-V CPU.

Once you pass the echo test, also try `sim/uart_parse_tb.v`.
This test combines both UART operations and string comparison.
It covers the basic functionality of the BIOS program, but is shorter and easier to debug than the BIOS testbench.
Make sure to compile the `.hex` file in the `software` directory first.

## BIOS and Programming your CPU
We have provided a BIOS program in `software/bios` that allows you to interact with your CPU and download other programs over UART.
The BIOS program is an infinite loop that reads from the UART, checks if the input string matches a known control sequence, and then performs an associated action.
For detailed information on the BIOS, see the [BIOS details document](./bios.md).

### Compiling the BIOS
Verify that the stack pointer and .text segment offset are set properly in `start.s` and `bios.ld` in `software/bios` directory.
Run `make` to generate `bios.hex`, which is used to initialize the BIOS memory (see `hardware/src/memories/bios_mem.v`).

### BIOS Testbench
Before running the BIOS program on your FPGA, run the `sim/bios_tb.v` testbench.
It testbench emulates the interaction between the host and your CPU via the serial lines orchestrated by the BIOS program.

It tests four basic functions of the BIOS program: sending an invalid command, storing to an address (in `imem` or `dmem`), loading from an address (in `imem` or `dmem`), and jumping to an address (from `bios_mem` to `imem`).

Once you pass the BIOS testbench, you can implement and test your processor on the FPGA!

### FPGA Build Flow
The build flow is identical to the labs.
Run `make synth` in `hardware` to synthesize `z1top`, run `make impl` to run place and route and bitstream generation, and run `make program` to program the bitstream onto the FPGA.
All the make targets are documented in the [hardware README](../hardware/README.md).

Make sure you **check the synthesis log** in `build/synth/synth.log` for unexpected warnings before proceeding to place and route.
If you see these info/warning messages in the log; they are OK and expected:
```text
WARNING: [Synth 8-6841] Block RAM (mem_reg) originally specified as a Byte Wide Write Enable RAM ...

INFO: [Synth 8-7052] The timing for the instance cpu/dmem/mem_reg_0_0 might be sub-optimal ...
```

### Testing the BIOS on the FPGA
Use screen to access the serial port:
```shell
screen $SERIALTTY 115200
# or
# screen /dev/ttyUSB0 115200
```

Press the reset button to make the CPU PC go to the start of BIOS memory.

Close screen using `Ctrl-a Shift-k`, or other students won't be able to use the serial port!
If you can't access the serial port you can run `killscreen` to kill all screen sessions.

#### BIOS Commands
If all goes well, you should see a `151 >` prompt after pressing return. The following commands are available:

- `jal <address>`: Jump to address (hex).
- `sw, sb, sh <data> <address>`: Store data (hex) to address (hex).
- `lw, lbu, lhu <address>`: Prints the data at the address (hex).

(if you want to backspace, press `Ctrl + Backspace`)

As an example, running `sw cafef00d 10000000` should write to the data memory and running `lw 10000000` should print the output `10000000: cafef00d`.
Please also pay attention that writes to the instruction memory (`sw ffffffff 20000000`) do not write to the data memory, i.e. `lw 10000000` still should yield `cafef00d`.

##### Loading New Programs
In addition to the command interface, the BIOS allows you to load programs to the CPU.
**With screen closed**, run:
```shell
./scripts/hex_to_serial <hex_file> <address>
```

This script stores the `.hex` file at the specified hex address.
In order to write into both the data and instruction memories, **remember to set the top nibble of the address to 0x3**.
(i.e. `./scripts/hex_to_serial ../software/echo/echo.hex 30000000`, assuming `echo.ld` sets the base address to `0x10000000`).

You also need to ensure that the stack and base address are set properly.
For example, before making the `mmult` program you should set the set the base address to `0x10000000`.
Therefore, when loading the `mmult` program you should load it at the base address: `./scripts/hex_to_serial software/mmult/mmult.hex 30000000`.
Then, you can jump to the loaded `mmult` program in in your screen session by using `jal 10000000`.

## Target Clock Frequency
By default, the CPU clock frequency is set at 50MHz.
It should be easy to meet timing at 50 MHz.
Look at the timing report (`build/impl/post_route_timing_summary.rpt`) to see if timing is met.
If you failed, the timing reports specify the critical path you should optimize.

Details on how to build your FPGA design with a different clock frequency are mentioned in the spec.

## Matrix Multiply
To check the correctness and performance of your processor we have provided a benchmark in `software/mmult` which performs matrix multiplication.
You should be able to load it into your processor in the same way as loading the `echo` program.

This program computes `S=AB`, where `A` and `B` are `64 X 64` matrices.
The program will print a checksum and the counters discussed in [Memory Mapped IO](#memory-mapped-io).
The correct checksum is `0001f800`.
If you do not get this, there is likely a problem in your CPU with one of the instructions that is used by the BIOS but not mmult.

The matrix multiply program requires that the stack pointer and the offset of the .text segment be set properly, otherwise the program will not execute properly.

The stack pointer (set in `start.s`) should start near the top of DMEM to avoid corrupting the program instructions and data.
It should be set to `0x1000fff0` and the stack grows downwards.

The .text segment offset (set in `mmult.ld`) needs to accommodate the full set of instructions and static data (three `64 X 64` matrices) in the mmult binary.
It should be set to the base of DMEM: `0x10000000`.

The program will also output the values of your instruction and cycle counters (in hex).
These can be used to calculate the CPI for this program.
Your target CPI should **not be greater than 1.2**.

If your CPI exceeds this value, you will need to modify your datapath and pipeline to reduce the number of bubbles inserted for resolving control hazards (since they are the only source of extra latency in our processor).
This might involve performing naive branch prediction or moving the jalr address calculation to an earlier stage.


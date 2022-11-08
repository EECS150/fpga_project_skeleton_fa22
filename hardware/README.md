# Some available commands

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

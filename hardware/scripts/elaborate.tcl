source ./target.tcl

# Read Verilog source files
if {[string trim ${RTL}] ne ""} {
  read_verilog -v ${RTL}
}

# Read user constraints
if {[string trim ${CONSTRAINTS}] ne ""} {
  read_xdc ${CONSTRAINTS}
}

# Only elaborate RTL (don't synthesize to netlist)
synth_design -verilog_define SYNTHESIS -verilog_define ABS_TOP=${ABS_TOP} -top ${TOP} -part ${FPGA_PART} -include_dirs ${ABS_TOP}/src/riscv_core -rtl

# write_checkpoint doesn't work:
# Vivado% write_checkpoint -force z1top_post_elab.dcp
# ERROR: [Common 17-69] Command failed: Checkpoints are not supported for RTL designs

# Open the schematic visualization
start_gui

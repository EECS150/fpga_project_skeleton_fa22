source ../target.tcl

# Read Verilog source files
if {[string trim ${RTL}] ne ""} {
  read_verilog -sv ${RTL}
}

# Read user constraints
if {[string trim ${CONSTRAINTS}] ne ""} {
  read_xdc ${CONSTRAINTS}
}

synth_design -verilog_define SYNTHESIS -verilog_define ABS_TOP=${ABS_TOP} -top ${TOP} -part ${FPGA_PART} -include_dirs ${ABS_TOP}/src/riscv_core

write_checkpoint -force ${TOP}.dcp
report_timing_summary -file post_synth_timing_summary.rpt
report_drc -file post_synth_drc.rpt
report_utilization -file post_synth_utilization.rpt
write_verilog -force -file post_synth.v
write_xdc -force -file post_synth.xdc

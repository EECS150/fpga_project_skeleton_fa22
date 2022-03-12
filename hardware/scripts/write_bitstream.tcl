
#set project_name "z1top"
set project_name [lindex $argv 0]
set target_clock [lindex $argv 1]

set sources_file scripts/${project_name}.tcl

if {![file exists $sources_file]} {
  puts "Invalid project name!"
  exit
}
open_project ${project_name}_proj/${project_name}_proj.xpr

if {${project_name} eq "z1top_axi"} {
  set f_mhz [expr int(1000 / ${target_clock})]
  set f_hz  [expr int(1000000000 / ${target_clock})]

  open_bd_design ${project_name}_proj/${project_name}_proj.srcs/sources_1/bd/z1top_axi_bd/z1top_axi_bd.bd
  set current_f_hz [get_property CONFIG.CPU_CLOCK_FREQ [get_bd_cells z1top_axi_0]]
  # apply new clock target
  if {${f_hz} != ${current_f_hz}} {
    set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ ${f_mhz} CONFIG.PCW_USE_M_AXI_GP0 {0} CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {1}] [get_bd_cells processing_system7_0]
    set_property -dict [list CONFIG.CPU_CLOCK_FREQ ${f_hz}] [get_bd_cells z1top_axi_0]
    set ps_clk [get_property CONFIG.FREQ_HZ [get_bd_pin processing_system7_0/FCLK_CLK0]]
    set_property -dict [list CONFIG.FREQ_HZ ${ps_clk}] [get_bd_intf_pins z1top_axi_0/interface_aximm]
    save_bd_design
  }
  update_compile_order -fileset sources_1
  set_property top z1top_axi_bd_wrapper [current_fileset]
}

update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1
wait_on_run synth_1 -verbose

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {   
  error "ERROR: synth_1 failed"   
} 

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1 -verbose

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {   
  error "ERROR: impl_1 failed"   
} 

# Backup bitstream
file mkdir bitstream_files
file copy -force [glob ${project_name}_proj/${project_name}_proj.runs/impl_1/*.bit] bitstream_files/${project_name}.bit

if {${project_name} eq "z1top_axi"} {
file mkdir bitstream_files/sdk
write_hwdef -force  -file bitstream_files/sdk/hwdef.zip
exec unzip -o bitstream_files/sdk/hwdef.zip -d bitstream_files/sdk
}

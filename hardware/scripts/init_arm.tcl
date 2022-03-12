
set project_name z1top_axi

# Change this number based on your assigned port number (Lab 1)
set port_number 3121

connect -url tcp:127.0.0.1:${port_number}

source bitstream_files/sdk/ps7_init.tcl
targets -set -nocase -filter {name =~"APU*"} -index 0
loadhw -hw bitstream_files/sdk/hwdef.xml -mem-ranges [list {0x40000000 0xbfffffff}]
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"} -index 0
stop
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "ARM*#0"} -index 0
rst -processor
targets -set -nocase -filter {name =~ "ARM*#0"} -index 0
dow ../arm_baremetal_app/system/Debug/system.elf
configparams force-mem-access 0
con

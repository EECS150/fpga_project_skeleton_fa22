
set project_name z1top_axi
connect -url tcp:127.0.0.1:3121
source ${project_name}_proj/${project_name}_proj.sdk/ps7_init.tcl
targets -set -nocase -filter {name =~"APU*"} -index 0
loadhw -hw ${project_name}_proj/${project_name}_proj.sdk/hwdef.xml -mem-ranges [list {0x40000000 0xbfffffff}]
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"} -index 0
stop
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "ARM*#0"} -index 0
rst -processor
targets -set -nocase -filter {name =~ "ARM*#0"} -index 0
dow system/Debug/system.elf
configparams force-mem-access 0
con

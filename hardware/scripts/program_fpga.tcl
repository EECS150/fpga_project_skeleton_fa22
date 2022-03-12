
set bitstream_file [lindex $argv 0]

if {![file exists $bitstream_file]} {
    puts "Invalid bitstream file!"
    exit
}

# Change this number based on your assigned port number (Lab 1)
set port_number 3121

open_hw
connect_hw_server -url localhost:${port_number}
open_hw_target

set_property PROGRAM.FILE ${bitstream_file} [get_hw_devices xc7z020_1]

current_hw_device [get_hw_devices xc7z020_1]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7z020_1] 0]
program_hw_devices [get_hw_devices xc7z020_1]
refresh_hw_device [lindex [get_hw_devices xc7z020_1] 0]

## Source: https://reference.digilentinc.com/_media/reference/programmable-logic/pynq-z1/pynq-z1_c.zip
##

##RGB LEDs

set_property -dict {PACKAGE_PIN L15 IOSTANDARD LVCMOS33} [get_ports {LEDS[4]}]
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS33} [get_ports {LEDS[5]}]

##LEDs

set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {LEDS[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {LEDS[1]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {LEDS[2]}]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {LEDS[3]}]

##Buttons

set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {BUTTONS[0]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {BUTTONS[1]}]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33} [get_ports {BUTTONS[2]}]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33} [get_ports {BUTTONS[3]}]

##Switches

set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[0]}]
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33} [get_ports {SWITCHES[1]}]

## Clock signal 125 MHz

set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports CLK_125MHZ_FPGA]
create_clock -period 8.000 -name CLK_125MHZ_FPGA -waveform {0.000 4.000} -add [get_ports CLK_125MHZ_FPGA]

#set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports CTS]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports FPGA_SERIAL_TX]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 IOB TRUE} [get_ports FPGA_SERIAL_RX]
#set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports RTS]

##Audio Out

set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 IOB TRUE} [get_ports { AUD_PWM }]; #IO_L20N_T3_34 Sch=aud_pwm
set_property -dict { PACKAGE_PIN T17   IOSTANDARD LVCMOS33 } [get_ports { AUD_SD }]; #IO_L20P_T3_34 Sch=aud_sd

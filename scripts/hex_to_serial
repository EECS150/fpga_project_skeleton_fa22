#!/usr/bin/env python3
# ported from /home/ff/eecs151/tools-151/bin/coe_to_serial
import os
import serial
import sys
import time

# Windows
if os.name == 'nt':
    ser = serial.Serial()
    ser.baudrate = 115200
    ser.port = 'COM11' # CHANGE THIS COM PORT
    ser.open()
else:
    ser = serial.Serial('/dev/ttyUSB0')
    ser.baudrate = 115200

if len(sys.argv) != 3:
    print("Usage: hex_to_serial <hex file> <base address>\nExample: hex_to_serial echo.hex 30000000")
    sys.exit(1)

#input("Open a serial program in another terminal, then hit Enter")

addr = int(sys.argv[2], 16);
with open(sys.argv[1], "r") as f:
    program = f.readlines()
if ('@' in program[0]):
    program = program[1:] # remove first line '@0'
program = [inst.rstrip() for inst in program]
size = len(program)*4 # in bytes

# write a newline to clear any input tokens before entering the command
command = "\n\rfile {:08x} {:d} ".format(addr, size)
print("Sending command: {}".format(command))
for char in command:
    ser.write(bytearray([ord(char)]))
    time.sleep(0.01)

for inst_num, inst in enumerate(program):
    for char in inst:
        ser.write(bytearray([ord(char)]))
        time.sleep(0.001)
    time.sleep(0.001)
    if (inst_num == len(program)-1):
        print("Sent {:d}/{:d} bytes".format(4+inst_num*4, size), end='\n')
    else:
        print("Sent {:d}/{:d} bytes".format(4+inst_num*4, size), end='\r')

print("Done")

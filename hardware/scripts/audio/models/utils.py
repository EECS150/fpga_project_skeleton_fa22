from typing import List, Dict
import math

from FixedPoint import FXnum


def generate_verilog_rom(data: List[FXnum], name: str) -> str:
    address_bits = math.ceil(math.log2(len(data)))
    num_rows = 2**address_bits
    data_bits = len(data[0].toBinaryString().replace('.', ''))

    # vlog = "module {} (input [{}:0] address, output reg [{}:0] data, output [{}:0] last_address);\n".format(name, address_bits - 1, data_bits - 1, address_bits - 1)
    # vlog = vlog + "  assign last_address = {};\n".format((min(len(data) - 1, num_rows - 1)))
    vlog = "module {} (input [{}:0] address, output reg [{}:0] data);\n".format(name, address_bits - 1, data_bits - 1)
    vlog = vlog + "  always @ (*) begin\n"
    vlog = vlog + "    case(address)\n"

    for i in range(0, num_rows):
        if i >= len(data):  # Write a 0
            vlog = vlog + "      {}'d{}: data = {}'d{};\n".format(address_bits, i, data_bits, 0)
        else:
            vlog = vlog + "      {}'d{}: data = {}'b{};\n".format(address_bits, i, data_bits, data[i].toBinaryString().replace('.', ''))

    vlog = vlog + "    endcase\n"
    vlog = vlog + "  end\n"
    vlog = vlog + "endmodule"
    return vlog


# A map from keyboard key to a frequency in Hz
# See: https://en.wikipedia.org/wiki/Piano_key_frequencies
# 'z' -> ',' maps to C3 -> C4
note_map: Dict[str, float] = {
    'Z': 65.4064,
    'S': 69.2957,
    'X': 73.4162,
    'D': 77.7817,
    'C': 82.4069,
    'V': 87.3071,
    'G': 92.4986,
    'B': 97.9989,
    'H': 103.826,
    'N': 110.000,
    'J': 116.541,
    'M': 123.471,
    '<': 130.813,

    'z': 130.813,
    's': 138.591,
    'x': 146.832,
    'd': 155.563,
    'c': 164.814,
    'v': 174.614,
    'g': 184.997,
    'b': 195.998,
    'h': 207.652,
    'n': 220.000,
    'j': 233.082,
    'm': 246.942,
    ',': 261.626,

    'q': 261.626,
    '2': 277.183,
    'w': 293.665,
    '3': 311.127,
    'e': 329.628,
    'r': 349.228,
    '5': 369.994,
    't': 391.127,
    '6': 415.305,
    'y': 440.000,
    '7': 466.164,
    'u': 493.883,
    'i': 523.251,

    'Q': 523.251,
    '@': 554.365,
    'W': 587.330,
    '#': 622.254,
    'E': 659.255,
    'R': 698.456,
    '%': 739.989,
    'T': 783.991,
    '^': 830.609,
    'Y': 880.000,
    '&': 932.328,
    'U': 987.767,
    'I': 1046.50
}

#!/usr/bin/env python3
from nco import NCOType, output_type
from FixedPoint import FXfamily, FXnum
import numpy as np

class Summer:
    def __init__(self, sine_shift: int, square_shift: int, triangle_shift: int, sawtooth_shift: int) -> None:
        self.shifts = [sine_shift, square_shift, triangle_shift, sawtooth_shift]

    def next_sample(self, nco_in: NCOType) -> FXnum:
        sample = FXnum(0, family=output_type)
        for wave,shift in zip(nco_in, self.shifts):
            sample = sample + (wave >> shift)
        return sample

class Truncator:
    def __init__(self, global_gain: int) -> None:
        self.global_gain = global_gain

    def next_sample(self, samp_in: FXnum) -> int:
        samp_gained = samp_in >> self.global_gain
        sample_bin = samp_gained.toBinaryString().replace('.', '')
        sample_bin_msbs = sample_bin[:12]
        #print("Sample bin: ", sample_bin)
        #print("MSB int val: ", int(sample_bin_msbs, 2))
        if sample_bin_msbs[0] == '1': # negative number
            return (~(-1*int(sample_bin_msbs, 2)) + 1) - 2**11
        else: # positive number
            return int(sample_bin_msbs, 2) + 2**11

if __name__ == "__main__":
    print("Testing truncator sweep")
    t = Truncator(0)
    for x in np.linspace(-8, 7.9, 10):
        print(t.next_sample(FXnum(x, output_type)))
    print("Testing truncator critical values")
    for x in [-8, 0, 8 - 2**-16]:
        print(t.next_sample(FXnum(x, output_type)))

    print("Testing summer")
    s = Summer(0, 32, 32, 32)
    for sample in np.linspace(-1, 1, 1000):
        out = s.next_sample([FXnum(sample, output_type), FXnum(-1, output_type), FXnum(-1, output_type), FXnum(-1, output_type)])
        assert abs(out - sample) < 1e-4

# Requires: pip install spfpm
from typing import List, Optional
from dataclasses import dataclass

from FixedPoint import FXnum

from models.lut import LUT


@dataclass
class NCO:
    luts: List[LUT]
    fsamp: float = 150e6 / 2500  # 60 kHz
    pa_bits: int = 24
    interpolate: bool = False
    pa: int = 0

    @property
    def max_pa_value(self) -> int:
        return 2**self.pa_bits - 1

    @property
    def zero(self) -> FXnum:
        return FXnum(0, family=self.luts[0].data_type)

    def __post_init__(self):
        assert len(set(x.data_type for x in self.luts)) == 1  # all LUTs should share the same number format
        assert len(set(x.num_rows for x in self.luts)) == 1  # all LUTs should have the same depth
        self.lut_addr_bits = self.luts[0].addr_bits

    def reset(self) -> None:
        self.pa = 0

    def freq_to_fcw(self, freq: float) -> int:
        return int(round((freq / self.fsamp) * 2**self.pa_bits))

    def fcw_to_freq(self, fcw: int) -> float:
        return (fcw * self.fsamp) / (2**self.pa_bits)

    @property
    def freq_resolution(self) -> float:
        return self.fsamp / (2**self.pa_bits)

    def msb_bits_of_pa(self) -> int:
        return (self.pa >> (self.pa_bits - self.lut_addr_bits)) & int('1'*self.lut_addr_bits, 2)

    def lsb_bits_of_pa(self) -> int:
        return self.pa & int('1' * (self.pa_bits - self.lut_addr_bits), 2)  # take LSB (N-M) bits of phase_acc

    def next_sample(self, fcw: Optional[int]) -> List[FXnum]:
        # take MSB lut_addr_bits bits of the PA to index the LUTs
        lut_index = self.msb_bits_of_pa()
        samples = []
        for lut in self.luts:
            if self.interpolate is False:
                samples.append(lut[lut_index])
            else:
                samp1 = lut[lut_index]
                samp2 = lut[(lut_index + 1) % lut.num_rows]
                residual = self.lsb_bits_of_pa()
                # Cast residual as fixed point
                residual = FXnum(residual / (2**(self.pa_bits - self.lut_addr_bits)), family=lut.data_type)
                diff = samp2 - samp1
                samples.append(samp1 + residual*diff)

        if fcw:
            self.pa = self.pa + fcw
        self.pa = self.pa % self.max_pa_value  # overflow on N bits
        return samples

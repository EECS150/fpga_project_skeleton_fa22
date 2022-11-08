from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import List
import math

from FixedPoint import FXfamily, FXnum
import numpy as np


@dataclass
class LUT(ABC):
    num_rows: int
    data_type: FXfamily
    data: List[FXnum] = field(init=False)

    def __post_init__(self):
        assert math.log2(self.num_rows).is_integer()
        self.data = self.generate()

    @abstractmethod
    def generate(self) -> List[FXnum]:
        raise NotImplementedError

    def binary_entries(self) -> List[str]:
        return [x.toBinaryString().replace('.', '') for x in self.data]

    def __getitem__(self, idx: int) -> FXnum:
        return self.data[idx]

    @property
    def addr_bits(self) -> int:
        return int(math.log2(self.num_rows))


class SineLUT(LUT):
    def generate(self) -> List[FXnum]:
        sine_lut_float = [np.sin(i * 2 * np.pi / self.num_rows) for i in range(self.num_rows)]
        return [FXnum(x, family=self.data_type) for x in sine_lut_float]


# TODO: the three LUT types below don't work properly
class SquareLUT(LUT):
    def generate(self) -> List[FXnum]:
        return [FXnum(1, family=self.data_type) for x in range(int(self.num_rows / 2))] + \
               [FXnum(-1, family=self.data_type) for x in range(int(self.num_rows / 2))]


class TriangleLUT(LUT):
    def generate(self) -> List[FXnum]:
        triangle_lut_float = [np.max(1 - np.abs(x)) for x in np.linspace(-1, 1, self.num_rows)]
        triangle_lut_float = [x * 2 - 1 for x in triangle_lut_float]  # scale to range from -1 to 1
        return [FXnum(x, family=self.data_type) for x in triangle_lut_float]


class SawtoothLUT(LUT):
    def generate(self) -> List[FXnum]:
        sawtooth_lut_float = [x - np.floor(x) for x in np.linspace(0, 1 - 1e-16, self.num_rows)]
        sawtooth_lut_float = [x * 2 - 1 for x in sawtooth_lut_float]  # scaling again
        return [FXnum(x, family=self.data_type) for x in sawtooth_lut_float]

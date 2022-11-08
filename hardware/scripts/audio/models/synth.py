from dataclasses import dataclass, field
from typing import List

from FixedPoint import FXnum

from models.nco import NCO


@dataclass
class Synth:
    carrier_ncos: List[NCO]
    modulator_ncos: List[NCO]
    modulator_idx_shift: int = field(default=0)
    modulator_fcw: int = field(default=0)
    fcws: List[int] = field(init=False)
    note_enabled: List[bool] = field(init=False)
    # TODO: implement mixer

    def __post_init__(self):
        assert len(self.carrier_ncos) == len(self.modulator_ncos)
        assert all(self.carrier_ncos[0].fsamp == x.fsamp for x in self.carrier_ncos)
        assert all(self.modulator_ncos[0].fsamp == x.fsamp for x in self.modulator_ncos)
        self.fcws = [0] * len(self.carrier_ncos)
        self.note_enabled = [False] * len(self.carrier_ncos)

    def next_sample(self) -> FXnum:
        modulator_samples = [nco.next_sample(self.modulator_fcw if en else None)[0] for nco, en in zip(self.modulator_ncos, self.note_enabled)]
        # print("Mod Sample:", modulator_samples[0].scaledval)
        freq_modulated_fcws = [fcw + (mod_samp.scaledval << self.modulator_idx_shift) for fcw, mod_samp in zip(self.fcws, modulator_samples)]
        # print("Modulated FCWs:", freq_modulated_fcws)
        carrier_samples = [nco.next_sample(fcw if en else None)[0] for nco, fcw, en in zip(self.carrier_ncos, freq_modulated_fcws, self.note_enabled)]
        # print("Carrier Sample:", carrier_samples[0].scaledval)
        return sum(carrier_samples)

#!/usr/bin/env python3

from dataclasses import dataclass
from nco import NCO, output_type
from Blocks import Summer, Truncator
from FixedPoint import FXnum
import wave
import struct

@dataclass
class Patch:
    sine_shift: int
    square_shift: int
    triangle_shift: int
    sawtooth_shift: int
    global_gain: int

pure_sine = Patch(0, 32, 32, 32, 0)
pure_triangle = Patch(32, 32, 0, 32, 0)
harmonics = Patch(0, 0, 32, 32, 0)



# A base models that doesn't use the truncator at the end
class Synth:
    def __init__(self, fsamp: float, patch: Patch) -> None:
        self.nco = NCO(fsamp, interpolate = True)
        self.summer = Summer(patch.sine_shift, patch.square_shift, patch.triangle_shift, patch.sawtooth_shift)
        self.truncator = Truncator(patch.global_gain)
        self.playing_note = False
        self.note_freq = 0

    def start_note(self, freq: float) -> None:
        self.nco.reset()
        self.note_freq = freq
        self.playing_note = True

    def release_note(self) -> None:
        self.playing_note = False

    def next_sample(self) -> int:
        nco_out = self.nco.next_sample_f(self.note_freq)
        summer_out = self.summer.next_sample(nco_out)
        if self.playing_note:
            return summer_out
        else:
            return FXnum(0, output_type)

# A monophonic models that uses the truncator at the output of 1 base models
class MonoSynth(Synth):
    def next_sample(self) -> int:
        nco_out = self.nco.next_sample_f(self.note_freq)
        summer_out = self.summer.next_sample(nco_out)
        truncator_out = self.truncator.next_sample(summer_out)
        if self.playing_note:
            return int(truncator_out)
        else:
            return 0

# A polyphonic models that uses the truncator at the output of N base synths after summing
class PolySynth:
    def __init__(self, fsamp: float, patch: Patch, polyphony: int) -> None:
        self.synths = [Synth(fsamp, patch) for s in range(polyphony)]
        self.active = [False]*polyphony
        self.notes = [0]*polyphony
        self.truncator = Truncator(patch.global_gain)

    def start_note(self, freq: float) -> None:
        for idx,synth in enumerate(self.synths):
            if not self.active[idx]:
                synth.start_note(freq)
                self.active[idx] = True
                self.notes[idx] = freq
                break

    def release_note(self, freq: float) -> None:
        for idx,note in enumerate(self.notes):
            if freq == note and self.active[idx]:
                self.synths[idx].release_note()
                self.active[idx] = False
                self.notes[idx] = freq
                break

    def next_sample(self) -> int:
        sample = FXnum(0, output_type)
        for synth in self.synths:
            sample = sample + synth.next_sample()
        return self.truncator.next_sample(sample)

if __name__ == "__main__":
    fsamp = 30e3

    s = MonoSynth(fsamp, pure_sine)
    #s = PolySynth(fsamp, pure_sine, 4)
    s.start_note(220)
    samples = [s.next_sample() for x in range(10000)]
    s.start_note(440)
    samples.extend([s.next_sample() for x in range(10000)])
    s.start_note(880)
    samples.extend([s.next_sample() for x in range(10000)])

    for s in samples:
        print(s)

    output_wav = wave.open('models.wav','w')
    output_wav.setparams((2,2,int(fsamp),0,'NONE','not compressed'))
    values = []
    for s in samples:
        result = int(s)
        packed_value = struct.pack('h',result)
        values.append(packed_value)
        values.append(packed_value)
    value_str = b''.join(values)
    output_wav.writeframes(value_str)
    output_wav.close()

    import matplotlib.pyplot as plt
    plt.plot(samples)
    plt.show()

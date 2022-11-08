import math
import numpy as np
from scipy import signal
import matplotlib.pyplot as plt
import random
import wave
import struct
import sys

# This function converts a number to fixed point representation of a certain 
# resolution. The numbers are limited to between -1 and 1, so there is no 
# integer but only fractions.
def resolution_limit(number, res):
	sign = 0
	if (number < 0):
		sign = 1

	number = abs(number)
	bin_rep = []
	for i in range(res):
		if (number >= 1/(2**(i+1))):
			number = number - 1/(2**(i+1))
			bin_rep.append(1)
		else:
			bin_rep.append(0)

	result = 0	
	for j in range(res):
		result += 1/(2**(j+1))*bin_rep[j]

	return  -1*result if sign else result


# This function generates three types of waves: sine, square and sawtooth for a
# given time point and frequency
def wave_generator(time, melody, time_unit, signal_type):

	# sine wave
	if (signal_type == 1):
		wave_out = math.sin(2 * math.pi * melody * time * time_unit)

	# square wave
	elif (signal_type == 2):
		if ((time * time_unit) % (1/melody) < (1/melody)/2):
			wave_out = 1
		else:
			wave_out = -1

	# sawtooth wave
	elif (signal_type == 3):
		wave_out = 2*melody*((time_unit*time)%(1/melody))-1
	else:
		wave_out = 0
	
	return wave_out


# State Variable Filter
def svf(din, res):

	# coefficients F and Q
	F = 2*math.sin(math.pi*fc*time_unit)
	F = resolution_limit(F, res)
	# a typical number of Q is sqrt(2), but it would require more complicated
	# arithmetic, so we use 1 for simplicity
	Q = 1

	# x[n] - yl[n] - Q*yb[n]
	yh = din[0] - din[1] - Q * din[2] 
	# limit resolution after each operation to avoid overflow
	yh = resolution_limit(yh,res) 
	
	# F*yh[n] + yb[n-1]
	yb = F * yh + din[2] 
	yb = resolution_limit(yb,res) 
	
	# F*yb[n-1] + yl[n-1]
	yl = F * yb + din[1] 
	yl = resolution_limit(yl,res)
	
	return [yl, yb, yh]

# melody (integer): tone to play
# attack_release (tuple): absolute time for attack and release
# fc (integer): corner frequency of SVF filter
# time_unit (float): sampling period of input signal
# res: resolution of data and coefficient
def synthesizer(melody, attack_release, fc, time_unit, res):

	# input wave
	waves = np.zeros((len(melody)+1,),dtype=np.float64) 
	# Final output
	waves_out = np.zeros((len(melody)+1,),dtype=np.float64)
	# lowpass output of SVF 
	waves_lp = np.zeros((len(melody)+1,),dtype=np.float64) 
	# highpass output of SVF
	waves_hp = np.zeros((len(melody)+1,),dtype=np.float64)
	# bandpass output of SVF 
	waves_bp = np.zeros((len(melody)+1,),dtype=np.float64) 
	state = 0

	for time in range(len(melody)):
		
		# generates wave based on frequency
		wave = wave_generator(time, melody[time], time_unit, 1) 
		wave = resolution_limit(wave,res)
		waves[time] = wave

		# Pass data through SVF filter
		if (time == 0):
			[yl, yb, yh] = svf([wave, 0.0, 0.0, 0.0], res)
		else:
			[yl, yb, yh] = svf([wave, waves_lp[time-1], waves_bp[time-1], waves_hp[time-1]], res)
		
		waves_lp[time] = yl
		waves_hp[time] = yh
		waves_bp[time] = yb


		# A(D)SR: in this section, we implement attack, sustain and release.
		# "attack_release" is a tuple that contains the attack and release time,
		# in hardware this will be implemented as key press and key release.
		# The duration of attack and release is customizable.

		# state --- 0: quiet, 1: attack, 2: sustain, 3: release
		
		if (time == attack_release[0]):
			state = 1
		elif ((time - attack_release[0]) == 4096): # play with this number to mimic actual instrument
			state = 2
		elif (time == attack_release[1]):
			state = 3
		elif ((time - attack_release[1]) == 4096):
			state = 0

		# change output based on state
		if (state == 0):
			waves_out[time] = 0
		elif (state == 1):
			waves_out[time] = waves_lp[time] * (time - attack_release[0]) * 0.000244140625 # 1/4096 in fixed point
		elif (state == 2):
			waves_out[time] = waves_lp[time]
		elif (state == 3):
			waves_out[time] = waves_lp[time] * (4096 - time + attack_release[1]) * 0.000244140625 
		else:
			waves_out[time] = 0

		time = time + 1
	return waves, waves_out



###############################################################################################################


fs = 44100 # sampling frequency 44.1KHz
time_unit = 1/fs # sampling period
res = 9 # resolution of data & coefficient
melody = [100] * 60000 # array of frequencies to be played (100Hz)
fc = 10000 # corner frequency of filter, play with this yourself
attack,release = (1000,30000) # onset time of attack and release
waves, waves_out = synthesizer(melody, (attack,release), fc, time_unit, res)
plt.plot(waves)
plt.plot(waves_out)
plt.show()

# write to wav file
output_wav = wave.open('piano_note.wav','w')
output_wav.setparams((2,2,44100,0,'NONE','not compressed'))
values = []
for note in waves_out:
	result = int(note * 20000)
	packed_value = struct.pack('h',result)
	values.append(packed_value)
	values.append(packed_value)

value_str = b''.join(values)
output_wav.writeframes(value_str)
output_wav.close()
sys.exit(0)






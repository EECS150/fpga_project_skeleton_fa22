#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory_map.h"

#define VOICES 1

#define SET_MOD_FCW 1
#define SET_MOD_SHIFT 2
#define START_PLAY 3
#define STOP_PLAY 4
#define SET_SYNTH_SHIFT 5
#define RESET 6

typedef void (*entry_t)(void);

void mmio_cdc() {
    MMIO_CPU_REQ = 1;
    while (!MMIO_CPU_ACK) ;
    MMIO_CPU_REQ = 0;
    while (MMIO_CPU_ACK) ;
}

uint32_t byte_array_to_int(int8_t arr[4]) {
    return (arr[3] << 24) | (arr[2] << 16) | (arr[1] << 8) | (arr[0]);
}

uint32_t read_word() {
    int8_t buffer[4];
    for (int i = 0; i < 3; ++i) {
        buffer[i] = uread_int8();
    }
    buffer[3] = 0;
    return byte_array_to_int(buffer);
}

uint32_t voice_active_to_en(uint8_t arr[VOICES]) {
    uint32_t en = 0;
    for (int i = 0; i < VOICES; ++i) {
        en = en | ((arr[i] & 0x1) << i);
    }
    return en;
}

int main(void) {
    uwrite_int8s("\r\n");
    //uwrite_int8s("Piano running, exit screen");
    MMIO_NOTE_EN = 0;
    MMIO_CPU_REQ = 0;
    MMIO_MOD_SHIFT = 0;
    MMIO_MOD_FCW = 0;
    MMIO_SYNTH_SHIFT = 0;
    mmio_cdc();

    uint8_t voice_active[VOICES];
    uint32_t voice_start_time[VOICES];
    uint32_t voice_fcw[VOICES];

    for (int i = 0; i < VOICES; ++i) {
        voice_active[i] = 0;
        voice_start_time[i] = 0;
        voice_fcw[i] = 0;
    }

    for ( ; ; ) {
        int8_t cmd = uread_int8();
        if (cmd == SET_MOD_FCW) {
            MMIO_MOD_FCW = read_word();
            mmio_cdc();
        } else if (cmd == SET_MOD_SHIFT) {
            MMIO_MOD_SHIFT = (uint32_t)uread_int8();
            mmio_cdc();
        } else if (cmd == SET_SYNTH_SHIFT) {
            MMIO_SYNTH_SHIFT = (uint32_t)uread_int8();
            mmio_cdc();
        } else if (cmd == START_PLAY) {
            uint32_t fcw = read_word();
            // If we're already playing this fcw, discard this command
            int8_t already_playing = 0;
            for (int i = 0; i < VOICES; ++i) {
                if (voice_active[i] && (voice_fcw[i] == fcw)) {
                    already_playing = 1;
                }
            }
            if (already_playing) {
                continue;
            }

            // Find a free voice that we can use
            int free_voice = -1;
            for (int i = 0; i < VOICES; ++i) {
                if (!voice_active[i]) {
                    free_voice = i;
                    break;
                }
            }

            // If a free voice doesn't exist, we have to evict the oldest note
            if (free_voice == -1) {
                uint32_t oldest_start_time = 0xFFFFFFFF;
                for (int i = 0; i < VOICES; ++i) {
                    if (voice_active[i] && (voice_start_time[i] < oldest_start_time)) {
                        oldest_start_time = voice_start_time[i];
                        free_voice = i;
                    }
                }
            }

            // Update program state
            voice_active[free_voice] = 1;
            voice_fcw[free_voice] = fcw;
            voice_start_time[free_voice] = CYCLE_COUNTER;

            // Begin playing the note on the free/evicted voice
            uint32_t fcw_addr = MMIO_CAR_FCW_BASE + (4*free_voice);
            (*((volatile uint32_t*)fcw_addr)) = fcw;
            MMIO_NOTE_EN = voice_active_to_en(voice_active);
            mmio_cdc();
        } else if (cmd == STOP_PLAY) {
            uint32_t fcw = read_word();
            // Find the voice that's playing this note (may not exist if evicted)
            int voice = -1;
            for (int i = 0; i < VOICES; ++i) {
                if (voice_active[i] && (voice_fcw[i] == fcw)) {
                    voice = i;
                }
            }

            // If there is no matching voice, discard this command
            if (voice == -1) {
                continue;
            }

            // Update program state
            voice_active[voice] = 0;
            voice_fcw[voice] = 0;
            voice_start_time[voice] = 0xFFFFFFFF;

            // Stop playing the note
            MMIO_NOTE_EN = voice_active_to_en(voice_active);
            mmio_cdc();
        } else if (cmd == RESET) {
            MMIO_NOTE_EN = 0;
            MMIO_CPU_REQ = 0;
            MMIO_MOD_SHIFT = 0;
            MMIO_MOD_FCW = 0;
            MMIO_SYNTH_SHIFT = 0;
            mmio_cdc();

            for (int i = 0; i < VOICES; ++i) {
                voice_active[i] = 0;
                voice_start_time[i] = 0;
                voice_fcw[i] = 0;
            }
        }
        LED_CONTROL = voice_active_to_en(voice_active);
    }
    return 0;
}

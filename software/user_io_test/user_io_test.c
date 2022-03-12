#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory_map.h"

typedef void (*entry_t)(void);

#define BUFFER_LEN 128

int8_t* read_token(int8_t* b, uint32_t n, int8_t* ds)
{
    for (uint32_t i = 0; i < n; i++) {
        int8_t ch = uread_int8();
        for (uint32_t j = 0; ds[j] != '\0'; j++) {
            if (ch == ds[j]) {
                b[i] = '\0';
                return b;
            }
        }
        b[i] = ch;
    }
    b[n - 1] = '\0';
    return b;
}

void decode_and_print_button(uint32_t button_state) {
    if (button_state & 0x1) {
        uwrite_int8s("\tButton 0 Push Detected\r\n");
    }
    if (button_state & 0x2) {
        uwrite_int8s("\tButton 1 Push Detected\r\n");
    }
    if (button_state & 0x4) {
        uwrite_int8s("\tButton 2 Push Detected\r\n");
    }
}

int main(void) {

    uwrite_int8s("\r\n");

    for ( ; ; ) {
        uwrite_int8s("user_io> ");

        int8_t buffer[BUFFER_LEN];
        int8_t* input = read_token(buffer, BUFFER_LEN, " \x0d");

        if (strcmp(input, "read_buttons") == 0) {
            // Read from the GPIO FIFO
            while (!GPIO_FIFO_EMPTY) {
                uint32_t button_state = GPIO_FIFO_DATA;
                decode_and_print_button(button_state);
            }
        } else if (strcmp(input, "read_switches") == 0) {
            uint32_t switch_state = SWITCHES;
            uwrite_int8s("\tSwitches set to ");
            uwrite_int8s(uint32_to_ascii_hex(switch_state, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        } else if (strcmp(input, "led") == 0) {
            uint32_t led_control = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            LED_CONTROL = led_control;
        } else if (strcmp(input, "exit") == 0) {
            uint32_t bios = ascii_hex_to_uint32("40000000");
            entry_t start = (entry_t) (bios);
            start();
        } else {
            uwrite_int8s("\tUnrecognized token: ");
            uwrite_int8s(input);
            uwrite_int8s("\r\n");
        }
    }

    return 0;
}

#include "ascii.h"
#include "uart.h"
#include "string.h"
#include "memory_map.h"

int8_t* read_n(int8_t*b, uint32_t n) {
    for (uint32_t i = 0; i < n;  i++) {
        b[i] =  uread_int8();
    }
    b[n] = '\0';
    return b;
}

int8_t* read_token(int8_t* b, uint32_t n, int8_t* ds) {
    uint32_t i = 0;
    while (i < n) {
        int8_t ch = uread_int8();
        if (ch == '\x08') { // backspace character
            if (i == 0)
                uwrite_int8('\x20'); // space
            else {
                b[i] = '\0'; // null current idx in buffer
                i = i - 1;
                uwrite_int8s("\x20\x08"); // space + backspace
            }
        } else {
            for (uint32_t j = 0; ds[j] != '\0'; j++) {
                if (ch == ds[j]) {
                    b[i] = '\0';
                    return b;
                }
            }
            b[i] = ch;
            i = i + 1;
        }
    }
    b[n - 1] = '\0';
    return b;
}

void store(uint32_t address, uint32_t length) {
    for (uint32_t i = 0; i*4 < length; i++) {
        int8_t buffer[9];
        int8_t* ascii_instruction = read_n(buffer,8);
        volatile uint32_t* p = (volatile uint32_t*)(address+i*4);
        *p = ascii_hex_to_uint32(ascii_instruction);
    }
}


#define BUFFER_LEN 128

typedef void (*entry_t)(void);

int main(void) {
    uwrite_int8s("\r\n");

    for ( ; ; ) {
        uwrite_int8s("151> ");

        int8_t buffer[BUFFER_LEN];
        int8_t* input = read_token(buffer, BUFFER_LEN, " \x0d");

        if (strcmp(input, "file") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t file_length = ascii_dec_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            store(address, file_length);
        } else if (strcmp(input, "jal") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            entry_t start = (entry_t)(address);
            start();
        } else if (strcmp(input, "lw") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            volatile uint32_t* p = (volatile uint32_t*)(address);

            uwrite_int8s(uint32_to_ascii_hex(address, buffer, BUFFER_LEN));
            uwrite_int8s(":");
            uwrite_int8s(uint32_to_ascii_hex(*p, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        } else if (strcmp(input, "lhu") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            volatile uint16_t* p = (volatile uint16_t*)(address);

            uwrite_int8s(uint32_to_ascii_hex(address, buffer, BUFFER_LEN));
            uwrite_int8s(":");
            uwrite_int8s(uint16_to_ascii_hex(*p, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        } else if (strcmp(input, "lbu") == 0) {
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            volatile uint8_t* p = (volatile uint8_t*)(address);

            uwrite_int8s(uint32_to_ascii_hex(address, buffer, BUFFER_LEN));
            uwrite_int8s(":");
            uwrite_int8s(uint8_to_ascii_hex(*p, buffer, BUFFER_LEN));
            uwrite_int8s("\r\n");
        } else if (strcmp(input, "sw") == 0) {
            uint32_t word = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            volatile uint32_t* p = (volatile uint32_t*)(address);
            *p = word;
        } else if (strcmp(input, "sh") == 0) {
            uint16_t half = ascii_hex_to_uint16(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            volatile uint16_t* p = (volatile uint16_t*)(address);
            *p = half;
        } else if (strcmp(input, "sb") == 0) {
            uint8_t byte = ascii_hex_to_uint8(read_token(buffer, BUFFER_LEN, " \x0d"));
            uint32_t address = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));

            volatile uint8_t* p = (volatile uint8_t*)(address);
            *p = byte;
        } else if (strcmp(input, "led") == 0) {
            uint32_t toggle_array = ascii_hex_to_uint32(read_token(buffer, BUFFER_LEN, " \x0d"));
            LED_CONTROL = toggle_array;
        } else {
            uwrite_int8s("\n\rUnrecognized token: ");
            uwrite_int8s(input);
            uwrite_int8s("\n\r");
        }
    }

    return 0;
}

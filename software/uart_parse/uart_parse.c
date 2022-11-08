#include "memory_map.h"
#include "uart.h"
#include "string.h"

int8_t* read_n(int8_t*b, uint32_t n) {
    for (uint32_t i = 0; i < n;  i++) {
        b[i] =  uread_int8();
    }
    b[n] = '\0';
    return b;
}

int8_t* read_token(int8_t* b, uint32_t n, int8_t* ds) {
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

#define BUFFER_LEN 16
int main(void) {
    csr_tohost(0);
    uwrite_int8s("\r\n151> ");
    int8_t buffer[BUFFER_LEN];
    int8_t* input = read_token(buffer, BUFFER_LEN, " \x0d");
    if (strcmp(input, "xyz") == 0) {
        csr_tohost(1);
    } else {
        csr_tohost(2);
    }
    return 0;
}

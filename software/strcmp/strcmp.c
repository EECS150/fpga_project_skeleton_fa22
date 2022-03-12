#include "string.h"

#define csr_tohost(csr_val) { \
    asm volatile ("csrw 0x51e,%[v]" :: [v]"r"(csr_val)); \
}

int main(void) {
    csr_tohost(0);
    char str[10] = "EECS151";

    if (strcmp(str ,"EECS151") == 0) {
        // pass
        csr_tohost(1);
    } else {
        // fail code 2
        csr_tohost(2);
    }

    // spin
    for( ; ; ) {
        asm volatile ("nop");
    }
}

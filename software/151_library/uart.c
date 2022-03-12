#include "uart.h"

void uwrite_int8(int8_t c)
{
    while (!UTRAN_CTRL) ;
    UTRAN_DATA = c;
}

void uwrite_int8s(const int8_t* s)
{
    for (int i = 0; s[i] != '\0'; i++) {
        uwrite_int8(s[i]);
    }
}

int8_t uread_int8(void)
{
    while (!URECV_CTRL) ;
    int8_t ch = URECV_DATA;
    if (ch == '\x0d') {
        uwrite_int8s("\r\n");
    } else {
        uwrite_int8(ch);
    }
    return ch;
}

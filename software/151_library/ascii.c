#include "ascii.h"

#define DEFINE_FROM_ASCII_DEC(type) \
type##_t ascii_dec_to_##type(const char* s) \
{ \
    type##_t t = 0; \
    for (uint32_t i = 0; i < (((sizeof(type##_t)/sizeof(uint8_t))<<1)+1) && s[i] != '\0'; i++) { \
        if (s[i] >= '0' && s[i] <= '9') { \
            t = (t << 3) + (t << 1) + (s[i] - '0'); \
        } \
    } \
    return t; \
}

DEFINE_FROM_ASCII_DEC(uint8)
DEFINE_FROM_ASCII_DEC(uint16)
DEFINE_FROM_ASCII_DEC(uint32)

#define DEFINE_FROM_ASCII_HEX(type) \
type##_t ascii_hex_to_##type(const char* s) \
{ \
    type##_t t = 0, i = 0; \
    for ( ; i < ((sizeof(type##_t)/sizeof(uint8_t))<<1) && s[i] != '\0'; i++) { \
        if (s[i] >= '0' && s[i] <= '9') { \
            t = (t << 4) + (s[i] - '0'); \
        } \
        if (s[i] >= 'a' && s[i] <= 'f') { \
            t = (t << 4) + (s[i] - 'a' + 10); \
        } \
        if (s[i] >= 'A' && s[i] <= 'F') { \
            t = (t << 4) + (s[i] - 'A' + 10); \
        } \
    } \
    return t; \
}

DEFINE_FROM_ASCII_HEX(uint8)
DEFINE_FROM_ASCII_HEX(uint16)
DEFINE_FROM_ASCII_HEX(uint32)

#define DEFINE_TO_ASCII_HEX(type) \
int8_t* type##_to_ascii_hex(type##_t x, int8_t* buffer, uint32_t n) \
{ \
    uint32_t i = 0; \
    uint32_t m = ((sizeof(type##_t) / sizeof(uint8_t)) << 1); \
    for ( ; i < m && i + 1 < n; i++) { \
        int8_t t = (x >> ((m - 1 - i) << 2)) & 0xf; \
        if (t >= 0 && t <= 9) { \
            buffer[i] = t + '0'; \
        } \
        if (t >= 0xa && t <= 0xf) { \
            buffer[i] = (t - 0xa) + 'a'; \
        } \
    } \
    buffer[i] = '\0'; \
    return buffer; \
}

DEFINE_TO_ASCII_HEX(uint8)
DEFINE_TO_ASCII_HEX(uint16)
DEFINE_TO_ASCII_HEX(uint32)

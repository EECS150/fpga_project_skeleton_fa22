#ifndef ASCII_H_
#define ASCII_H_

#include "types.h"

#define DECLARE_FROM_ASCII_HEX(type) \
type##_t ascii_hex_to_##type(const char* s);

DECLARE_FROM_ASCII_HEX(uint8)
DECLARE_FROM_ASCII_HEX(uint16)
DECLARE_FROM_ASCII_HEX(uint32)

#define DECLARE_FROM_ASCII_DEC(type) \
type##_t ascii_dec_to_##type(const char* s);

DECLARE_FROM_ASCII_DEC(uint8)
DECLARE_FROM_ASCII_DEC(uint16)
DECLARE_FROM_ASCII_DEC(uint32)

#define DECLARE_TO_ASCII_HEX(type) \
int8_t* type##_to_ascii_hex(type##_t x, int8_t* buffer, uint32_t n);

DECLARE_TO_ASCII_HEX(uint8)
DECLARE_TO_ASCII_HEX(uint16)
DECLARE_TO_ASCII_HEX(uint32)

#endif

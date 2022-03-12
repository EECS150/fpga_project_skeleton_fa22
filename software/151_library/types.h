#ifndef TYPES_H_
#define TYPES_H_

typedef unsigned char  uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int   uint32_t;

typedef char  int8_t;
typedef short int16_t;
typedef int   int32_t;

#define NULL 0

#define TRUE  1
#define FALSE 0

#define HILO16(x, y) (((x & 0xFFFF) << 16) | (y & 0xFFFF))

#define HI16(x) ((x >> 16) & 0xFFFF)
#define LO16(x) (x & 0xFFFF)

#define HILO8(x, y) (((x & 0xFF) << 8) | (y & 0xFF))

#define HI8(x) ((x >> 8) & 0xFF)
#define LO8(x) (x & 0xFF)

#define HILO4(x, y) (((x & 0xF) << 4) | (y & 0xF))

#define HI4(x) ((x >> 4) & 0xF)
#define LO4(x) (x & 0xF)

#endif

#ifndef MEMORY_H_
#define MEMORY_H_

#include "types.h"

#define DECLARE_FILLV(type) \
type##_t* fill_##type##v(type##_t* v, type##_t val, uint32_t n);

DECLARE_FILLV(int8)
DECLARE_FILLV(uint8)

#endif

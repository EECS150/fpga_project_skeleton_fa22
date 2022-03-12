#include "memory.h"

#define DEFINE_FILLV(type) \
type##_t* fill_##type##v(type##_t* v, type##_t val, uint32_t n) \
{ \
    for (uint32_t i = 0; i < n; i++) { \
        v[i] = val; \
    } \
    return v; \
}

DEFINE_FILLV(int8)
DEFINE_FILLV(uint8)

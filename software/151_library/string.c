#include "string.h"

int32_t strcmp(const int8_t* s0, const int8_t* s1) {
/*
    uwrite_int8s("\n\rComparing ");
    uwrite_int8s(s0);
    uwrite_int8s("|");
    uwrite_int8s("with ");
    uwrite_int8s(s1);
    uwrite_int8s("|");
    uwrite_int8s("\n\r");
*/
  for (uint32_t i = 0; ; i++) {
        if (s0[i] != s1[i]) {
            return 1;
        }
        if (s0[i] == '\0') {
            break;
        }
    }
    return 0;
}

uint32_t strlen(const int8_t* s) {
    uint32_t i = 0;
    for ( ; s[i] != '\0'; i++) ;
    return i;
}

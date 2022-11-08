#include "types.h"

#define csr_tohost(csr_val) { \
    asm volatile ("csrw 0x51e,%[v]" :: [v]"r"(csr_val)); \
}

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))

#define GPIO_FIFO_EMPTY (*((volatile uint32_t*)0x80000020) & 0x01)
#define GPIO_FIFO_DATA (*((volatile uint32_t*)0x80000024))
#define SWITCHES (*((volatile uint32_t*)0x80000028) & 0x03)
#define LED_CONTROL (*((volatile uint32_t*)0x80000030))

#define MMIO_CAR_FCW_0 (*((volatile uint32_t*)0x80000100))
#define MMIO_CAR_FCW_BASE 0x80000100

#define MMIO_MOD_FCW (*((volatile uint32_t*)0x80000200))
#define MMIO_MOD_SHIFT (*((volatile uint32_t*)0x80000204))
#define MMIO_NOTE_EN (*((volatile uint32_t*)0x80000208))
#define MMIO_SYNTH_SHIFT (*((volatile uint32_t*)0x8000020C))

#define MMIO_CPU_REQ (*((volatile uint32_t*)0x80000210))
#define MMIO_CPU_ACK (*((volatile uint32_t*)0x80000214) & 0x1)

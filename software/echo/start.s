.section    .start
.global     _start

_start:
    li      sp, 0x10001000
    jal     main

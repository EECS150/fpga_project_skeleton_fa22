.section    .start
.global     _start

_start:
    li      sp, 0x10000600
    jal     main

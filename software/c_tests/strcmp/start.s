.section    .start
.global     _start

_start:
    li      sp, 0x1000fff0
    jal     main

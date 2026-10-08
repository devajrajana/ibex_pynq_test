.section .text
.global _start

_start:
    li sp, 0x00003FFC
    call main

1:
    j 1b

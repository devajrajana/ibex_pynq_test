ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 32K
    RAM (rw)  : ORIGIN = 0x00008000, LENGTH = 16K
}

SECTIONS
{
    .text : ALIGN(4)
    {
        *(.text.start)
        *(.text*)
        *(.rodata*)
    } > ROM

    .data : ALIGN(4)
    {
        *(.data*)
        *(.sdata*)
    } > RAM

    .bss : ALIGN(4)
    {
        *(.bss*)
        *(.sbss*)
        *(COMMON)
    } > RAM
}

OUTPUT_ARCH( "riscv" )
ENTRY( _start )

SECTIONS
{
    . = 0x40000000;
    .text : {
        * (.start);
        * (.text);
    }
}

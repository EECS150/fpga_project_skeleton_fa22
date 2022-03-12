SECTIONS
{
    . = 0x40000000;
    .text : {
        * (.start);
        * (.text);
    }
}

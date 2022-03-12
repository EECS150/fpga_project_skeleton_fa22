#define RECV_CTRL (*((volatile unsigned int*)0x80000000) & 0x02)
#define RECV_DATA (*((volatile unsigned int*)0x80000004) & 0xFF)

#define TRAN_CTRL (*((volatile unsigned int*)0x80000000) & 0x01)
#define TRAN_DATA (*((volatile unsigned int*)0x80000008))

int main(void)
{
    for ( ; ; )
    {
        while (!RECV_CTRL) ;
        char byte = RECV_DATA;
        while (!TRAN_CTRL) ;
        TRAN_DATA = byte;
    }

    return 0;
}

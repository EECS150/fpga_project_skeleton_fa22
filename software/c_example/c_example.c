int array[] = {3, 2, 4, 23, 32, 1};

char msg[] = "HELLO WORLD!!";

int main(void)
{
    int x = 100;

    int y = x + 500;

    unsigned int t = 1000;

    unsigned int r = 0xFFFFFFFF - t;

    char m = msg[3];

    msg[4] = 'B';
    msg[5] = 'C';
    msg[6] = 'D';
    msg[7] = 'E';

    char b = msg[4];
    char c = msg[5];
    char d = msg[6];
    char e = msg[7];

    return y;
}

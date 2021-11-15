int foo(int x)
{
    goto error;
    return 0;
error:
    return 1;
}

void loop(int x)
{
    {
loop:
        x++;
        if (x != 0) {
            goto loop;
        }
    }
}

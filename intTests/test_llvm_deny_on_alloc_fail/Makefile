CC=clang
CFLAGS=-g -emit-llvm

test.bc: test.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f test.bc

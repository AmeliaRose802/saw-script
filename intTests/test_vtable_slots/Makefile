.PHONY: all clean

all: example.bc

example.bc: example.cpp
	clang++ -std=c++17 -emit-llvm -c -g example.cpp -o example.bc

clean:
	rm -f example.bc

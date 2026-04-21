# Makefile — Build pipeline for vtable dispatch verification example.

CXX       := clang++
CXXFLAGS  := -std=c++20 -O0 -emit-llvm

# ── Targets ─────────────────────────────────────────────────────────────────

all: vtable_dispatch.bc

# Build from C++ source (if clang++ is available).
vtable_dispatch.bc: vtable_dispatch.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Alternative: generate from LLVM IR text using Python + llvmlite.
generate:
	python gen_bitcode.py --ll

# Disassemble bitcode for inspection.
inspect: vtable_dispatch.bc
	llvm-dis vtable_dispatch.bc -o vtable_dispatch.ll

# Run SAW verification.
verify: vtable_dispatch.bc verify.saw
	saw verify.saw

clean:
	rm -f vtable_dispatch.bc vtable_dispatch.ll

.PHONY: all generate inspect verify clean

# Makefile — LTO devirtualization pipeline for SAW verification of C++ code.
#
# This demonstrates how to compile C++ with whole-program devirtualization so
# that SAW can verify functions whose virtual calls have been resolved to
# direct calls by the optimizer.
#
# Requirements: clang++, llvm-link, opt, llvm-dis (all from the same LLVM
# version), and saw.

CXX       := clang++
CXXFLAGS  := -std=c++20 -flto -fwhole-program-vtables -fvisibility=hidden -emit-llvm
LLVM_LINK := llvm-link
OPT       := opt

SOURCES   := example.cpp
OBJECTS   := $(SOURCES:.cpp=.bc)

# ── Targets ─────────────────────────────────────────────────────────────────

all: devirt.bc

# Step 1: Compile each source file to LLVM bitcode.
#   -flto                    — emit LTO-compatible bitcode
#   -fwhole-program-vtables  — embed type metadata for devirtualization
#   -fvisibility=hidden      — allow the optimizer to assume no external overrides
#   -emit-llvm -c            — produce .bc instead of native object files
%.bc: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Step 2: Link all bitcode files into a single module.
#   With multiple translation units this is where cross-TU information merges.
combined.bc: $(OBJECTS)
	$(LLVM_LINK) $^ -o $@

# Step 3: Optimize with -O2.  The whole-program-devirtualization pass replaces
#   indirect virtual calls with direct calls wherever the concrete type is
#   known.  Inspect the result with `make inspect`.
devirt.bc: combined.bc
	$(OPT) -O2 $< -o $@

# ── Utilities ───────────────────────────────────────────────────────────────

# Disassemble devirt.bc so you can check that devirtualization happened.
# Look for `double_concrete` — it should contain a direct multiply, not an
# indirect call through a vtable.
inspect: devirt.bc
	$(OPT) -O2 combined.bc -S -o - | grep -A 20 'define.*double_concrete'

# Run SAW verification on the devirtualized bitcode.
verify: devirt.bc verify.saw
	saw verify.saw

clean:
	rm -f *.bc *.ll

.PHONY: all inspect verify clean

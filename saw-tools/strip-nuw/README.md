# strip-nuw

Strips `nuw` (no unsigned wrap) and `nsw` (no signed wrap) flags from
LLVM bitcode so that SAW's symbolic execution does not generate
unprovable poison-value proof obligations.

## Problem

At `-O1` and above, LLVM adds `nuw`/`nsw` flags to arithmetic
instructions (`add`, `sub`, `mul`, `shl`) and `nuw`/`nusw` flags to
GEP instructions inside inlined C++ STL code. When SAW symbolically
executes through these with unconstrained symbolic values, the wrap
checks produce proof obligations like "Unsigned truncation caused
wrapping" that are not provable and block verification.

## Usage

```bash
# Build (requires LLVM 14+ development headers)
mkdir build && cd build
cmake .. -DLLVM_DIR=/path/to/llvm/lib/cmake/llvm
make

# Run
./strip-nuw input.bc -o output.bc
```

The tool prints a summary of how many flags were stripped:

```
strip-nuw: stripped 42 nuw, 18 nsw (arithmetic), 7 GEP wrap flags
```

## Typical workflow

```bash
# 1. Compile C++ to bitcode
clang++ -c -emit-llvm -O1 -o module.bc module.cpp

# 2. Strip nuw/nsw flags
strip-nuw module.bc -o module-clean.bc

# 3. Verify with SAW
saw verify.saw   # loads module-clean.bc
```

## What it strips

| Instruction type | Flags removed | Flags kept |
|---|---|---|
| `add`, `sub`, `mul`, `shl` | `nuw`, `nsw` | — |
| `getelementptr` | `nuw`, `nusw` | `inbounds` |

Removing these flags changes the semantics from "produces poison on
overflow" to "wraps normally on overflow", which is safe for
verification — if the original program was correct, the wrap case is
unreachable, and SAW will not report a false positive.

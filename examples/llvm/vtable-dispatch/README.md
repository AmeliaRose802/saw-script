# Vtable Dispatch Verification with SAW

This example demonstrates how to verify C++ virtual method calls with SAW using
`llvm_bind_method` to intercept indirect calls through vtable pointers.

## The Pattern: IsMachineEnabled

This proof-of-concept models the `IsMachineEnabled` function from MSP's
`KeyExchangeSession`. The function has exactly **one vtable call**:

```
IKeyStore->GetMachineConfiguration(containerId)
  → returns (KeyStoreOperationResult, ParsedConfig)
```

The decision logic is:
```
result = GetMachineConfiguration(containerId, &config)
return (result == SUCCESS && config.hostDataEnabled != 0)
```

## How It Works

### The Problem

C++ virtual method calls compile to **indirect calls** through a vtable:

```llvm
%vtable = load ptr, ptr %obj          ; load vtable pointer
%slot   = getelementptr ptr, ptr %vtable, i64 1  ; index to slot 1
%fn     = load ptr, ptr %slot         ; load function pointer
%result = call i32 %fn(...)           ; indirect call
```

SAW cannot follow indirect calls because it doesn't know which function the
pointer targets at verification time.

### The Solution: `llvm_bind_method`

`llvm_bind_method` tells SAW to intercept the vtable dispatch:

```saw
// Assume a spec for the virtual method
get_config_lemma <- llvm_unsafe_assume_spec m "get_config" get_config_spec;

// Bind vtable slot 1 to that spec
llvm_bind_method keystore 1 get_config_lemma;
```

During verification, SAW:
1. Allocates a synthetic vtable in memory
2. Installs the override at the specified slot
3. Writes the vtable pointer into the object at offset 0
4. When the indirect call loads from that slot, it resolves to the override
5. Proves the caller's return value matches the symbolic keystore result

### Memory Layout

```
keystore object:  [vtable_ptr | ... ]
                       │
                       ▼
synthetic vtable: [slot_0 | slot_1 | ... ]
                              │
                              ▼
                   [override handle → get_config_spec]
```

## Files

| File | Description |
|------|-------------|
| `vtable_dispatch.cpp` | C++ source showing the IsMachineEnabled pattern |
| `vtable_dispatch.ll` | LLVM IR with the vtable dispatch pattern |
| `vtable_dispatch.bc` | Pre-compiled LLVM bitcode |
| `verify.saw` | SAW proof that the return is `(ks_result == SUCCESS && host_enabled)` |
| `gen_bitcode.py` | Python script to regenerate bitcode (uses llvmlite) |
| `Makefile` | Build and verification pipeline |

## Running

### With pre-built bitcode

```bash
saw verify.saw
```

### From C++ source (requires clang++)

```bash
make
make verify
```

### Regenerate bitcode (requires Python + llvmlite)

```bash
pip install llvmlite
python gen_bitcode.py --ll
```

## Relationship to Real MSP Verification

This proof-of-concept verifies the same control-flow pattern as
`IsMachineEnabled` in the real MSP `KeyExchangeSession` bitcode
(`out/KeyExchangeSession_v20_clean.bc`) and proves the exact decision rule.

The differences from the real bitcode are:
- Simplified types: uses raw `i32` instead of C++ `std::tuple`
- Single vtable slot instead of full interface vtable
- No MSVC `std::basic_string` SSO complications (see saw-script-ygg)

That means the remaining gap to the real bitcode is ABI/layout modeling, not
the virtual-dispatch reasoning itself.

## Prerequisites

- **SAW** (the Software Analysis Workbench) — built with `llvm_bind_method`
  support (requires `enable_experimental`)
- For building from source: **clang++** (LLVM 14+)
- For bitcode regeneration: **Python 3** + **llvmlite**

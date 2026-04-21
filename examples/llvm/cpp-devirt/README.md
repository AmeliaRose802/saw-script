# LTO Devirtualization for C++ Verification with SAW

This example demonstrates how to use Clang's **LTO (Link-Time Optimization)**
with **whole-program devirtualization** to make C++ virtual method calls
amenable to verification with SAW.

## The Problem

SAW verifies LLVM bitcode by symbolically executing functions.  Virtual method
calls compile to **indirect calls** through a vtable pointer, and SAW cannot
follow indirect calls — it doesn't know which function the pointer targets at
verification time.

## The Solution: LTO Devirtualization

When the optimizer can prove the concrete type of an object, it replaces the
indirect vtable call with a **direct call** to the known implementation.  This
is called *devirtualization*.  After devirtualization, SAW can symbolically
execute the function normally.

### Compilation Pipeline

```
 ┌──────────┐     -emit-llvm -c      ┌──────────┐
 │ .cpp files│ ──────────────────────▶ │ .bc files │
 └──────────┘   -flto                 └──────────┘
                -fwhole-program-vtables       │
                -fvisibility=hidden           │ llvm-link
                                              ▼
                                       ┌────────────┐
                                       │ combined.bc │
                                       └────────────┘
                                              │ opt -O2
                                              ▼
                                       ┌──────────┐
                                       │ devirt.bc │  ← SAW verifies this
                                       └──────────┘
```

The key compiler flags:

| Flag                         | Purpose                                              |
|------------------------------|------------------------------------------------------|
| `-flto`                      | Emit LTO-compatible bitcode for cross-TU optimization |
| `-fwhole-program-vtables`    | Embed type metadata so the optimizer can devirtualize |
| `-fvisibility=hidden`        | Tell the optimizer no external code overrides vtables |
| `-emit-llvm -c`              | Output LLVM bitcode (`.bc`) instead of native objects |

### What Devirtualizes and What Doesn't

| Pattern                                   | Devirtualized? | Why                                       |
|-------------------------------------------|:--------------:|-------------------------------------------|
| Concrete object on stack: `Derived d; d.method()` | ✅ Yes  | Optimizer sees the exact type             |
| `new Derived()` returned immediately              | ✅ Yes  | Type visible through allocation           |
| Pointer/reference parameter: `Base* b`            | ❌ No   | Type unknown — could be any derived class |
| Factory function returning `Base*`                | ❌ No   | Type erased by the interface              |

## Running the Example

```bash
# Build the devirtualized bitcode
make

# (Optional) Inspect the IR to confirm devirtualization happened
make inspect
# Look for double_concrete — it should contain a direct `mul` or `shl`,
# not an indirect call through a vtable.

# Verify with SAW
make verify
```

### Prerequisites

- **clang++**, **llvm-link**, **opt**, **llvm-dis** — all from the same LLVM
  installation (LLVM 14+)
- **SAW** (the Software Analysis Workbench)

## What About Non-Devirtualized Calls?

For virtual calls that the optimizer *cannot* resolve — e.g.,
`apply_interface(Transformer* t, uint32_t x)` in this example — SAW needs
a way to bind a specific method implementation at verification time.

This capability is provided by `llvm_bind_method` (requires
`enable_experimental`), which lets you specify which concrete method a virtual
call should dispatch to during verification, even when the bitcode retains an
indirect call.

See the **[vtable-dispatch](../vtable-dispatch/)** example for a complete
proof-of-concept that uses `llvm_bind_method` to verify a function with
virtual dispatch — modeled after the IsMachineEnabled pattern from MSP's
KeyExchangeSession.

If `llvm_bind_method` is not available, the workaround is to ensure that the
code you verify only uses patterns that *do* devirtualize (see the table
above).

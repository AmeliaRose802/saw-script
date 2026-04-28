# Async Rust Verification with SAW

**Issue:** saw-script-rpm  
**Parent:** saw-script-q6z (EPIC: Support async Rust verification in SAW)

## Introduction

This document describes how to verify async Rust functions using SAW.
Async Rust functions are desugared by the compiler into coroutine state
machines that implement `Future::poll`. SAW can verify these by treating
the coroutine as a struct with a discriminant and saved state.

## Prerequisites

- SAW with MIR verification support
- `saw-rustc` for compiling Rust to MIR JSON
- `enable_experimental` for coroutine-related commands

## How Async Rust Works (for verification)

When you write:

```rust
async fn add_one(x: u32) -> u32 {
    x.wrapping_add(1)
}
```

The compiler produces a coroutine type with:
- A **discriminant** field (u32) indicating the state:
  - 0 = Unresumed (never polled)
  - 1 = Suspended (yielded, waiting to be polled again)
  - 3 = Returned (completed)
  - 4 = Panicked
- **Upvar** fields: captured variables from the async block
- **Saved local** fields: local variables preserved across yield points

## Step-by-Step Verification

### 1. Compile Rust to MIR

```bash
saw-rustc my_module.rs
# Produces my_module.linked-mir.json
```

### 2. Load the Module

```sawscript
enable_experimental;
m <- mir_load_module "my_module.linked-mir.json";
```

### 3. Verify Synchronous Helpers First

```sawscript
let add_one_spec = do {
    x <- mir_fresh_var "x" mir_u32;
    mir_execute_func [mir_term x];
    mir_return (mir_term {{ x + 1 : [32] }});
};
add_one_ov <- mir_verify m "my_module::add_one" [] false add_one_spec z3;
```

### 4. Construct Coroutine State (for async verification)

```sawscript
// Construct the initial coroutine state
let discr = mir_term {{ 0 : [32] }};  // Unresumed state
let upvar_x = mir_term {{ 42 : [32] }};
let initial_state = mir_coroutine_value discr [upvar_x];
```

### 5. Verify the Poll Function

```sawscript
// For a simple async fn that completes on first poll:
let poll_spec = do {
    // Allocate coroutine reference (Pin<&mut Self> erased to &mut Self)
    self_ref <- mir_alloc_mut coroutine_ty;
    x <- mir_fresh_var "x" mir_u32;
    let init = mir_coroutine_value (mir_term {{ 0 : [32] }}) [mir_term x];
    mir_points_to self_ref init;

    // Context (waker) — symbolic, not inspected
    cx_ref <- mir_alloc_mut context_ty;

    mir_execute_func [self_ref, cx_ref];

    // Returns Poll::Ready(x + 1)
    let result = mir_enum_value poll_adt "Ready" [mir_term {{ x + 1 : [32] }}];
    mir_return result;
};
```

### 6. Use as Override in Caller Verification

```sawscript
// When verifying code that .awaits:
let caller_spec = do {
    x <- mir_fresh_var "x" mir_u32;
    mir_execute_func [mir_term x];
    mir_return (mir_term {{ x + 2 : [32] }});
};
mir_verify m "my_module::caller" [poll_ov] false caller_spec z3;
```

## Key Commands

| Command | Purpose |
|---------|---------|
| `mir_coroutine_value discr fields` | Construct coroutine state |
| `mir_bind_method trait impl` | Bind dyn Trait method to impl |
| `mir_override_extern m name spec` | Override FFI function |
| `mir_enum_value adt variant fields` | Construct enum (Poll) value |

## Limitations

- Multi-poll (suspending) async functions require multiple specs
- The `Context`/`Waker` must be symbolically modeled
- Nested `.await` chains may need compositional verification
- `async_trait` desugaring adds extra indirection (see dv0)

## References

- [Coroutine TypeShape design](../developer/poll-override-matching-design.md)
- [Pin erasure](../developer/pin-erasure.md) (80n)
- [SAW MIR verification guide](../saw-user-manual/)

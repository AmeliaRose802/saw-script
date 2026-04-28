# Override Matching for Poll-Based Async Verification

**Issue:** saw-script-3ro  
**Parent:** saw-script-q6z (EPIC: Support async Rust verification in SAW)

## Background

Rust async functions desugar into state machines that implement `Future::poll`.
When verifying a caller that awaits an async function, SAW needs to match
override specs against `poll()` invocations.

## Design

### Poll Return Type

```rust
enum Poll<T> {
    Ready(T),    // discriminant 0
    Pending,     // discriminant 1
}
```

In MIR, `Poll<T>` is an enum with two variants. SAW can already handle enums
via `mir_enum_value`, so poll return values are constructible:

```sawscript
// Poll::Ready(42u32)
let ready_val = mir_enum_value poll_adt "Ready" [mir_term {{ 42 : [32] }}];

// Poll::Pending
let pending_val = mir_enum_value poll_adt "Pending" [];
```

### Override Matching Strategy

For a function `async fn foo(x: u32) -> u32`:

1. **First poll (initial):** The coroutine is in state 0 (Unresumed).
   Override spec should accept the initial coroutine value and return
   `Poll::Ready(result)` for simple non-suspending async functions.

2. **Multi-poll (suspending):** For async functions that suspend, the
   verifier needs multiple override specs — one per poll that advances
   the state machine:
   - Poll 1: state 0 → state 1, returns `Poll::Pending`
   - Poll 2: state 1 → state 3, returns `Poll::Ready(result)`

3. **Pin erasure:** The `poll` method signature is
   `fn poll(self: Pin<&mut Self>, cx: &mut Context) -> Poll<Output>`.
   With Pin erasure (80n), `Pin<&mut Self>` becomes `&mut Self`.

### Spec Pattern

```sawscript
// For a simple async fn that completes immediately:
let async_add_spec = do {
    self_ref <- mir_alloc_mut (mir_adt coroutine_adt);
    // Initial state: discriminant = 0 (Unresumed)
    discr <- mir_fresh_var "discr" mir_u32;
    mir_precond {{ discr == 0 }};
    x <- mir_fresh_var "x" mir_u32;
    let init_state = mir_coroutine_value (mir_term discr) [mir_term x];
    mir_points_to self_ref init_state;

    // Context can be symbolic (not used by simple functions)
    cx_ref <- mir_alloc_mut mir_usize;

    mir_execute_func [self_ref, cx_ref];

    // Returns Poll::Ready(x + 1)
    let result = mir_enum_value poll_adt "Ready" [mir_term {{ x + 1 : [32] }}];
    mir_return result;
};
```

## Open Questions

1. How to handle nested async calls (await chains)?
2. Should SAW auto-detect the number of polls needed?
3. How to model the `Context`/`Waker` argument?

## Implementation Plan

1. Ensure `mir_enum_value` works with Poll<T> (should already work)
2. Ensure `mir_coroutine_value` can construct initial state (done in c3n)
3. Add integration test with actual poll override (depends on xix, 6gb)
4. Document the override patterns (rpm)

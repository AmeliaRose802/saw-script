# SAWScript Exception Specification Commands — Design Document

**Issue:** saw-script-e01  
**Status:** Design  
**Depends on:** Exception lowering pass (`saw-tools/exception-lower/`)

## Motivation

C++ code that throws and catches exceptions requires special handling for SAW
verification. The exception lowering pass (`ExceptionLowerPass.cpp`) already
transforms EH constructs into explicit error-flag control flow, making the code
verifiable with standard `llvm_verify`. This document designs optional
SAWScript-level commands that provide a *higher-level* interface for specifying
exception behavior.

## Current Approach (Sufficient)

After running `exception-lower` on a bitcode module:

```sawscript
m <- llvm_load_module "lowered.bc";

// The lowered code exposes three globals:
//   @__exclow_error_flag     : i1   (1 = exception in flight)
//   @__exclow_error_typeinfo : i8*  (RTTI pointer of thrown exception)
//   @__exclow_error_value    : i8*  (pointer to exception object)

let my_spec = do {
    // Pre: no exception in flight
    flag_ptr <- llvm_alloc (llvm_int 1);
    llvm_points_to (llvm_global "__exclow_error_flag") (llvm_term {{ 0 : [1] }});

    llvm_execute_func [...];

    // Post: either flag=0 (success) or flag=1 (exception thrown)
    flag <- llvm_fresh_var "flag" (llvm_int 1);
    llvm_points_to (llvm_global "__exclow_error_flag") (llvm_term flag);
};
```

## Proposed Commands

### `llvm_may_throw`

Declares that the function under verification may throw an exception.
Generates the standard error-flag postcondition automatically.

```sawscript
llvm_may_throw;
// Equivalent to: postcond that __exclow_error_flag may be 0 or 1
```

**Semantics:** Adds a fresh Boolean to the postcondition representing
whether an exception was thrown. The verifier will check both paths.

### `llvm_no_throw`

Asserts the function does NOT throw.

```sawscript
llvm_no_throw;
// Equivalent to: postcond that __exclow_error_flag == 0
```

### `llvm_throws_type typeinfo_name`

Constrains the thrown exception type when `llvm_may_throw` is active.

```sawscript
llvm_may_throw;
llvm_throws_type "std::runtime_error";
// If flag==1, then __exclow_error_typeinfo points to _ZTISt13runtime_error
```

### `llvm_catch_spec type setup_block`

Specifies behavior in a catch handler for a particular exception type.

```sawscript
llvm_catch_spec "std::runtime_error" (\exc_ptr -> do {
    // exc_ptr : LLVMValue pointing to the exception object
    msg <- llvm_fresh_var "msg" (llvm_array 256 (llvm_int 8));
    llvm_points_to exc_ptr (llvm_struct_value [llvm_term msg]);
});
```

### `llvm_exception_value setup_value`

In a postcondition, constrains the exception value when one is thrown.

```sawscript
llvm_may_throw;
val <- llvm_fresh_var "exc_val" (llvm_int 32);
llvm_exception_value (llvm_term val);
llvm_postcond {{ val == 42 }};
```

## Implementation Strategy

All commands are **SAWScript-level sugar** that expand to standard
`llvm_points_to` and `llvm_precond`/`llvm_postcond` on the lowered
globals. No engine changes required.

### Implementation in Haskell (Builtins.hs)

```haskell
llvm_may_throw :: LLVMCrucibleSetupM ()
llvm_may_throw = LLVMCrucibleSetupM $ do
    -- Add postcondition: __exclow_error_flag is unconstrained (fresh)
    flag <- Setup.freshVariable "exception_flag" (LLVM.PrimType (LLVM.Integer 1))
    Setup.addPointsTo (llvm_global "__exclow_error_flag") flag

llvm_no_throw :: LLVMCrucibleSetupM ()
llvm_no_throw = LLVMCrucibleSetupM $ do
    -- Add postcondition: __exclow_error_flag == 0
    Setup.addPointsTo (llvm_global "__exclow_error_flag") (llvm_term (bvLit 1 0))
```

### Registration in Interpreter.hs

```haskell
, prim "llvm_may_throw"  "LLVMSetup ()"
  (pureVal llvm_may_throw)
  Experimental
  [ "Declare that the function may throw a C++ exception."
  , "Requires the module to have been processed by exception-lower."
  ]

, prim "llvm_no_throw"  "LLVMSetup ()"
  (pureVal llvm_no_throw)
  Experimental
  [ "Assert that the function does not throw any exception." ]
```

## Error-Flag Protocol

The lowering pass produces these three globals:

| Global | Type | Meaning |
|--------|------|---------|
| `__exclow_error_flag` | `i1` | 0 = normal, 1 = exception in flight |
| `__exclow_error_typeinfo` | `i8*` | Pointer to RTTI typeinfo of thrown exception |
| `__exclow_error_value` | `i8*` | Pointer to allocated exception object |

## Open Questions

1. **Nested exceptions:** The lowering pass handles `resume` by re-setting the
   flag. Should `llvm_catch_spec` support re-throw?

2. **Multiple catch clauses:** C++ try/catch can have multiple handlers. Should
   we provide `llvm_catch_all` or require individual `llvm_catch_spec` per type?

3. **noexcept verification:** Should `llvm_no_throw` automatically apply to
   functions declared `noexcept` in the original C++?

## Timeline

- Phase 1: `llvm_may_throw` and `llvm_no_throw` (sufficient for most uses)
- Phase 2: `llvm_throws_type` and `llvm_exception_value`
- Phase 3: `llvm_catch_spec` (requires more design for exception object layout)

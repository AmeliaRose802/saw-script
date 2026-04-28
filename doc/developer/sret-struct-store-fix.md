# Fix: sret Struct Store — Use `llvm_alias` Instead of `llvm_array`

**Issue:** saw-script-hu3  
**Status:** FIXED

## Problem

When verifying C++ functions that return structs via `sret` (struct return)
calling convention, SAW's memory model would reject struct-typed stores if
the `sret` allocation used `llvm_array` (byte-array type). The `_Tuple_val`
constructor memory store would fail because the LLVM struct type didn't match
the byte-array type.

## Root Cause

MSVC and Itanium ABI compilers emit `sret` parameters as pointers to named
LLVM struct types (e.g., `%class.std::tuple.89`). When the SAW specification
allocated the return buffer as `llvm_array N (llvm_int 8)`, the memory model
would see a type mismatch: the function writes a struct but the allocation
expects a byte array.

## Fix

Use `llvm_alias` with the actual named LLVM struct type:

```sawscript
// WRONG — byte-array allocation causes type mismatch
// ret_ptr <- llvm_alloc (llvm_array 48 (llvm_int 8));

// CORRECT — named struct type preserves type compatibility
ret_ptr <- llvm_alloc (llvm_alias "class.std::tuple.89");
```

## How to Find the Right Type Name

1. Use `llvm-dis` or SAW's error messages to find the struct type name
2. The LLVM IR will show: `%class.std::tuple.89 = type { ... }`
3. Strip the `%` prefix and use the name with `llvm_alias`

## Example

```sawscript
let create_key_spec = do {
    // sret allocation for std::tuple<bool, Key>
    ret_ptr <- llvm_alloc (llvm_alias "class.std::tuple.89");

    // ... other setup ...

    // The sret pointer is the first argument (MSVC convention)
    llvm_execute_func [ret_ptr, ...];

    // Read back the struct fields
    success <- llvm_fresh_var "success" (llvm_int 8);
    llvm_points_to ret_ptr (llvm_struct_value [...]);
};
```

## Verification

`CreateKey` now verifies successfully with z3 using this approach.

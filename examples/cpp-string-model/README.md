# C++ String Model for SAW

SAW overrides and Cryptol specs that replace the `std::basic_string` SSO
(Small String Optimization) layout with a flat byte-array model SAW can
reason about.

## The Problem

Both MSVC and GCC/Clang `std::basic_string` implementations use a
*discriminated union* for the Small String Optimization:

```
struct basic_string {
  union {
    char  _Buf[16];   // inline buffer for short strings (SSO)
    char* _Ptr;       // heap pointer for long strings
  };
  size_t _Size;
  size_t _Capacity;   // if _Capacity < 16 → SSO is active
};
```

SAW's LLVM memory model cannot represent this union because:

1. **Overlapping fields** – `_Buf` and `_Ptr` share the same memory, and the
   active variant is determined at runtime by comparing `_Capacity < 16`.
2. **Symbolic branching on layout** – SAW would need to fork on which union
   member is active, producing path explosion.
3. **Non-trivial constructors/destructors** – SSO transitions between inline
   and heap storage through complex control flow that SAW cannot easily
   symbolically execute.

## The Byte-Array Model

We replace the entire `basic_string` object with a simple triple:

```
struct saw_string_model {
  i8*  buf;   // pointer to a flat byte array (size = max capacity)
  i64  len;   // current logical length
  i64  cap;   // allocated capacity
};
```

Every `std::basic_string` method is overridden at the LLVM level to operate
on this representation instead of the real SSO layout.

## Files

| File | Description |
|------|-------------|
| `StringModel.cry` | Cryptol type and specs: `StringModel n`, equality, validity predicates |
| `string_overrides.saw` | SAWScript overrides for `size`, `data`, `c_str`, construct, assign, destructor |
| `HeapModel.cry` | Cryptol specs for heap allocation validation (`valid_alloc_size`, `alloc_result`) |
| `heap_overrides.saw` | SAWScript overrides for `operator new`/`delete` and STL allocators |
| `README.md` | This file |

## Quick Start

### 1. Build your C++ to LLVM bitcode

```bash
# MSVC (clang-cl)
clang-cl /clang:-emit-llvm -c -O1 -fno-exceptions my_code.cpp -o my_code.bc

# GCC/Clang
clang++ -emit-llvm -c -g -O1 -fno-exceptions my_code.cpp -o my_code.bc
```

### 2. Find the mangled symbol names

```bash
llvm-nm my_code.bc | grep -i 'basic_string'
```

### 3. Write a verification script

```saw
// Load modules
import "StringModel.cry";
include "string_overrides.saw";

m <- llvm_load_module "my_code.bc";

// Register string overrides (use the mangled names from step 2)
// Adjust MAX_LEN to your application's maximum string size.
let MAX_LEN = 256;

size_ov <- llvm_verify m "<mangled_size_symbol>"
             [] false (string_size_override MAX_LEN) z3;

data_ov <- llvm_verify m "<mangled_data_symbol>"
             [] false (string_data_override MAX_LEN) z3;

dtor_ov <- llvm_verify m "<mangled_destructor_symbol>"
             [] false (string_tidy_override MAX_LEN) z3;

// Use overrides compositionally
llvm_verify m "my_function"
  [size_ov, data_ov, dtor_ov]
  false my_function_spec z3;
```

### 4. Run SAW

```bash
export CRYPTOLPATH="examples/cpp-string-model"
saw my_verification.saw
```

## Using `llvm_fresh_string`

The main helper is `llvm_fresh_string`, which allocates a complete symbolic
string in one call:

```saw
include "string_overrides.saw";

let my_spec = do {
    // Create a symbolic string of up to 128 bytes
    s <- llvm_fresh_string "input" 128;

    // s.this_ptr  - the "this" pointer to pass to string methods
    // s.buf_ptr   - pointer to the byte content
    // s.buf       - Cryptol term for byte array
    // s.len       - Cryptol term for length (i64)
    // s.cap       - Cryptol term for capacity (i64)

    llvm_execute_func [ s.this_ptr ];

    // Assert something about the result using the Cryptol model
    llvm_return (llvm_term {{ string_length`{128} { buf = s.buf
                                                   , len = s.len
                                                   , cap = s.cap } }});
};
```

## Mangled Name Reference

Below are the typical mangled names for `std::basic_string<char>` methods
on MSVC and GCC/Clang. Use `llvm-nm` to find the exact names in your
bitcode, as they vary by compiler version and flags.

### MSVC (Microsoft ABI)

| Method | Mangled Name |
|--------|-------------|
| `size()` | `?size@?$basic_string@DU?$char_traits@D@std@@V?$allocator@D@2@@std@@QEBA_KXZ` |
| `c_str()` | `?c_str@?$basic_string@DU?$char_traits@D@std@@V?$allocator@D@2@@std@@QEBAPEBDXZ` |
| `data()` | `?data@?$basic_string@DU?$char_traits@D@std@@V?$allocator@D@2@@std@@QEBAPEBDXZ` |
| `assign(const char*, size_t)` | `?assign@?$basic_string@DU?$char_traits@D@std@@V?$allocator@D@2@@std@@QEAAAEAV12@PEBD_K@Z` |
| `~basic_string()` | `??1?$basic_string@DU?$char_traits@D@std@@V?$allocator@D@2@@std@@QEAA@XZ` |
| `operator[]` | `??A?$basic_string@DU?$char_traits@D@std@@V?$allocator@D@2@@std@@QEAAAEADH@Z` |

### GCC/Clang (Itanium ABI)

| Method | Mangled Name |
|--------|-------------|
| `size()` | `_ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4sizeEv` |
| `c_str()` | `_ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE5c_strEv` |
| `data()` | `_ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE4dataEv` |
| `assign(const char*, size_t)` | `_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6assignEPKcm` |
| `~basic_string()` | `_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEED1Ev` |
| `length()` | `_ZNKSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE6lengthEv` |

### libstdc++ (older, no `__cxx11` inline namespace)

| Method | Mangled Name |
|--------|-------------|
| `size()` | `_ZNKSs4sizeEv` |
| `c_str()` | `_ZNKSs5c_strEv` |
| `data()` | `_ZNKSs4dataEv` |

## Limitations

- **Fixed maximum size**: Each `llvm_fresh_string` call fixes a maximum
  buffer size at verification time. Choose a size large enough for your
  application.
- **No reallocation**: The model does not support strings that grow beyond
  their initial capacity. This is appropriate for verification where inputs
  are bounded.
- **Content beyond `len`**: Bytes in `buf` past index `len-1` are symbolic
  garbage. Specs should only reason about the first `len` bytes.
- **No null terminator**: The model does not enforce a NUL byte at
  `buf[len]`. If your code relies on `c_str()` returning a NUL-terminated
  buffer, add an explicit postcondition.

## Heap Allocator Overrides

The `heap_overrides.saw` file provides SAWScript overrides that model C++
`operator new` / `operator delete` and STL internal allocators.

### Why?

SAW's `llvm_alloc` requires a fixed type at verification time.  C++ heap
allocation (`operator new(size_t)`) takes a *symbolic* size.  These
overrides bridge the gap by:

1. Accepting a `max_size` parameter chosen at verification time.
2. Allocating a byte array of that fixed size via `llvm_alloc`.
3. Adding a precondition that the symbolic `size` argument ≤ `max_size`.
4. Modelling `operator delete` as a no-op (SAW manages memory lifetime).

### Available Overrides

| Override | Models | Itanium Symbol | MSVC Symbol |
|----------|--------|----------------|-------------|
| `operator_new_override max_size` | `operator new(size_t)` | `_Znwm` | `??2@YAPEAX_K@Z` |
| `operator_new_array_override max_size` | `operator new[](size_t)` | `_Znam` | `??_U@YAPEAX_K@Z` |
| `operator_delete_override` | `operator delete(void*)` | `_ZdlPv` | `??3@YAXPEAX@Z` |
| `operator_delete_array_override` | `operator delete[](void*)` | `_ZdaPv` | `??_V@YAXPEAX@Z` |
| `operator_delete_sized_override` | `operator delete(void*, size_t)` | `_ZdlPvm` | `??3@YAXPEAX_K@Z` |
| `stl_allocate_override max_size` | `_Allocate` / `_Buy_raw` / `allocator::allocate` | varies | varies |
| `stl_deallocate_override` | `_Deallocate` / `allocator::deallocate` | varies | varies |

### Quick Example

```saw
import "HeapModel.cry";
include "heap_overrides.saw";

m <- llvm_load_module "my_code.bc";

let MAX_ALLOC = 1024;

// Register overrides for operator new / delete
new_ov <- llvm_verify m "_Znwm"
            [] false (operator_new_override MAX_ALLOC) z3;

del_ov <- llvm_verify m "_ZdlPv"
            [] false operator_delete_override z3;

// Use compositionally
llvm_verify m "my_function"
  [new_ov, del_ov]
  false my_function_spec z3;
```

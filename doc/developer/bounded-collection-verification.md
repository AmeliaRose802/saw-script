# Bounded HashMap/Vec/String Verification Strategy for MIR

**Issue:** saw-script-kh2  
**Parent:** saw-script-3ea (EPIC: Close SAW MIR verification gaps)

## Problem

Production Rust code uses `HashMap`, `Vec`, and `String` extensively.
These are heap-allocated, dynamically-sized collections that can't be
directly represented as fixed-size symbolic values.

## Strategy: Bounded Verification

### Vec<T>

Model `Vec<T>` as a fixed-capacity array with a symbolic length:

```sawscript
// Vec<u32> with max capacity 10
let vec_u32_spec max_cap = do {
    len <- mir_fresh_var "len" mir_usize;
    mir_precond {{ len <= `max_cap }};

    // Allocate raw pointer to backing array
    buf <- mir_alloc_raw_ptr_const_multi max_cap mir_u32;

    // The Vec struct: { ptr, len, cap }
    let vec_val = mir_tuple [buf, mir_term len, mir_term {{ `max_cap : [64] }}];
    return vec_val;
};
```

### String

Model `String` as `Vec<u8>` with UTF-8 validity constraints:

```sawscript
// String with max length 256
let string_spec max_len = do {
    len <- mir_fresh_var "len" mir_usize;
    mir_precond {{ len <= `max_len }};

    buf <- mir_alloc_raw_ptr_const_multi max_len mir_u8;

    let str_val = mir_tuple [buf, mir_term len, mir_term {{ `max_len : [64] }}];
    return str_val;
};
```

### HashMap<K, V>

Model as a bounded association list or use uninterpreted functions:

```sawscript
// HashMap<u32, u32> as an uninterpreted lookup function
let hashmap_spec = do {
    // Model as: given a key, returns an Option<V>
    // Use mir_unint to keep the lookup abstract
    mir_unint ["hashmap_get"];
};
```

## Limitations

- Bounded verification only proves properties up to the bound
- HashMap ordering is non-deterministic (modeled as uninterpreted)
- Reallocation/growth not modeled (assume sufficient capacity)

## Implementation Plan

1. Create `lib/mir_collection_models.saw` with helper functions
2. Add Cryptol specs for collection operations
3. Test with simple Vec/String-using functions
4. Document bounded verification patterns

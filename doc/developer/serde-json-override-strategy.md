# Override Strategy for serde_json Proc-Macro-Generated MIR

**Issue:** saw-script-qb5  
**Parent:** saw-script-3ea (EPIC: Close SAW MIR verification gaps)

## Problem

`serde_json` uses proc macros (`#[derive(Serialize, Deserialize)]`) to
generate complex deserialization code. This generated MIR:

1. Contains deeply nested match arms for JSON structure
2. Uses trait objects (`dyn Deserializer`) for format abstraction
3. Calls into serde's visitor pattern (multiple virtual dispatch)
4. Produces very large MIR functions (100s of basic blocks)

Direct symbolic execution is impractical due to path explosion.

## Strategy: Override at Serialization Boundary

### Approach 1: Override serialize/deserialize directly

```sawscript
// Instead of verifying serde-generated code, assume specs for it
let deserialize_spec = do {
    // Input: a JSON byte buffer
    buf <- mir_alloc_raw_ptr_const_multi 1024 mir_u8;
    len <- mir_fresh_var "len" mir_usize;

    mir_execute_func [buf, mir_term len];

    // Output: a Result<MyStruct, Error>
    // Assume success path
    field1 <- mir_fresh_var "field1" mir_u32;
    field2 <- mir_fresh_var "field2" mir_u64;
    let result = mir_enum_value result_adt "Ok"
                   [mir_struct_value my_struct_adt [mir_term field1, mir_term field2]];
    mir_return result;
};

deser_ov <- mir_unsafe_assume_spec m "serde_json::from_slice" deserialize_spec;
```

### Approach 2: Override the Deserialize trait impl

```sawscript
// Override the generated Deserialize::deserialize for MyStruct
let deser_impl_spec = do {
    // The deserializer is a dyn Deserializer -- model abstractly
    deser_ref <- mir_alloc_mut mir_usize;  // opaque

    mir_execute_func [deser_ref];

    // Return Result<MyStruct, Error>
    field1 <- mir_fresh_var "f1" mir_u32;
    let ok_val = mir_enum_value result_adt "Ok"
                   [mir_struct_value my_struct_adt [mir_term field1]];
    mir_return ok_val;
};

deser_impl_ov <- mir_unsafe_assume_spec m
    "<MyStruct as serde::Deserialize>::deserialize"
    deser_impl_spec;
```

### Approach 3: Cryptol specification of JSON parsing

```cryptol
// Formal spec of what deserialize should produce
parse_my_struct : [n][8] -> Option MyStruct
parse_my_struct bytes =
    if valid_json bytes then
        Some (extract_fields bytes)
    else
        None
```

## Recommendations

1. **Never symbolically execute serde-generated code** — too complex
2. **Use `mir_unsafe_assume_spec`** at the serde boundary
3. **Write Cryptol specs** for the expected serialization format
4. **Verify business logic** separately from serialization
5. **Test serialization roundtrip** with concrete examples

## Patterns to Override

| Function | Strategy |
|----------|----------|
| `serde_json::from_str` | Assume spec: returns fresh struct |
| `serde_json::from_slice` | Assume spec: returns fresh struct |
| `serde_json::to_string` | Assume spec: returns fresh string |
| `<T as Deserialize>::deserialize` | Assume spec per type |
| `<T as Serialize>::serialize` | Assume spec per type |

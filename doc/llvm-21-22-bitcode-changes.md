# LLVM 21-22 Bitcode Format Changes

**Purpose**: Complete enumeration of new bitcode records and attributes added in LLVM 21 and 22 for updating llvm-pretty-bc-parser.

**Sources**:
- llvm/include/llvm/Bitcode/LLVMBitCodes.h (release/20.x vs release/22.x)
- llvm/include/llvm/IR/Attributes.td (release/22.x)

**Date**: 2026-04-21

---

## Summary

LLVM 22 introduces:
- **3 new parameter/function attributes** (ATTR_KIND codes 103-105)
- **2 new metadata record types** (METADATA codes 48-49)
- **1 new constants code** (CST_CODE 34)
- **1 new cast operation** (CAST 13)
- **2 new atomic RMW operations** (RMW 19-20)
- **1 new function instruction code** (FUNC_CODE 66)
- **1 new global value summary code** (FS 33)
- **Changes to existing record encodings** for FS_COMBINED_CALLSITE_INFO (28) and FS_COMBINED_ALLOC_INFO (29)

---

## 1. New TYPE_CODE_* Record Types

**None added in LLVM 21-22.**

The TYPE_CODE enumeration remains unchanged from LLVM 20:
- TYPE_CODE_NUMENTRY through TYPE_CODE_TARGET_TYPE (codes 1-26)

---

## 2. New FUNC_CODE_* Instruction Records

### FUNC_CODE_DEBUG_RECORD_DECLARE_VALUE = 66
**Added in**: LLVM 21 or 22
**Format**: `[DILocation, DILocalVariable, DIExpression, ValueAsMetadata]`
**Description**: Debug record for declare-style debug value intrinsics.

This is a new debug record type that extends the existing debug record infrastructure (which includes VALUE, ASSIGN, VALUE_SIMPLE, and LABEL variants).

---

## 3. New Parameter/Function Attributes

### ATTR_KIND_DEAD_ON_RETURN = 103
**Added in**: LLVM 22
**Name**: `dead_on_return`
**Properties**: ParamAttr, IntersectAnd
**Description**: Indicates that a parameter is dead (will not be accessed) upon function return.

**Importance**: This attribute appears in MSVC STL function signatures when compiled with LLVM 22. Supporting this attribute is **critical** for parsing LLVM 22 bitcode from Windows toolchains.

**Example usage**: Applied to parameters that are consumed by the function and guaranteed to be dead after normal return.

### ATTR_KIND_SANITIZE_ALLOC_TOKEN = 104
**Added in**: LLVM 21 or 22
**Name**: `sanitize_alloc_token`
**Properties**: FnAttr, IntersectPreserve
**Description**: Indicates that allocation token instrumentation is enabled for this function.

Part of the sanitizer instrumentation infrastructure for tracking memory allocations.

### ATTR_KIND_NO_CREATE_UNDEF_OR_POISON = 105
**Added in**: LLVM 21 or 22
**Name**: `nocreateundeforpoison`
**Properties**: FnAttr, IntersectAnd
**Description**: Result will not be undef or poison if all arguments are not undef and not poison.

This is a function attribute that provides stronger guarantees about the function's behavior with respect to undef and poison values in LLVM IR.

---

## 4. New Metadata Record Types

### METADATA_SUBRANGE_TYPE = 48
**Added in**: LLVM 21 or 22
**Format**: `[distinct, ...]`
**Description**: Subrange type metadata for Fortran array support.

This is one of the reserved codes (42-43) that were finally allocated for Fortran-specific debug information.

### METADATA_FIXED_POINT_TYPE = 49
**Added in**: LLVM 21 or 22
**Format**: `[distinct, ...]`
**Description**: Fixed-point type metadata.

Supports debug information for fixed-point arithmetic types (commonly used in embedded systems and signal processing).

---

## 5. New Constants Codes

### CST_CODE_PTRAUTH2 = 34
**Added in**: LLVM 21 or 22
**Format**: `[ptr, key, disc, addrdisc, deactivation_symbol]`
**Description**: Extended pointer authentication constant expression.

This extends CST_CODE_PTRAUTH (33) by adding a `deactivation_symbol` field. Pointer authentication is primarily used on ARM architectures (e.g., arm64e) for enhanced security.

---

## 6. New Cast Operations

### CAST_PTRTOADDR = 13
**Added in**: LLVM 21 or 22
**Description**: Pointer-to-address cast operation.

This is a new cast opcode in the CastOpcodes enumeration, used in constant expression casts (CST_CODE_CE_CAST).

---

## 7. New Atomic RMW Operations

### RMW_FMAXIMUM = 19
**Added in**: LLVM 21 or 22
**Description**: Atomic floating-point maximum operation.

Performs an atomic read-modify-write that computes the maximum of the current value and the operand, handling NaN values according to the IEEE 754-2019 maximum semantics.

### RMW_FMINIMUM = 20
**Added in**: LLVM 21 or 22
**Description**: Atomic floating-point minimum operation.

Performs an atomic read-modify-write that computes the minimum of the current value and the operand, handling NaN values according to the IEEE 754-2019 minimum semantics.

---

## 8. New Global Value Summary Codes

### FS_COMBINED_ALLOC_INFO_NO_CONTEXT = 33
**Added in**: LLVM 21 or 22
**Format**: `[nummib, numver, nummib x alloc type, numver x version]`
**Description**: Summary of combined index allocation memprof metadata, without context.

This is a variant of FS_COMBINED_ALLOC_INFO (29) that omits context radix tree information. Used in memory profiling (memprof) for ThinLTO.

---

## 9. Changes to Existing Record Encodings

### FS_COMBINED_CALLSITE_INFO (28) - Format Updated
**Old format (LLVM 20)**:
```
[valueid, context radix tree index, numver, numver x version]
```

**New format (LLVM 22)**:
```
[valueid, numstackindices, numver,
 numstackindices x stackidindex, numver x version]
```

**Impact**: The second field changed from a single `context radix tree index` to `numstackindices` followed by an array of `numstackindices x stackidindex`.

### FS_COMBINED_ALLOC_INFO (29) - Format Updated
**Old format (LLVM 20)**:
```
[nummib, numver,
 nummib x (alloc type, numstackids, numstackids x stackidindex),
 numver x version]
```

**New format (LLVM 22)**:
```
[nummib, numver,
 nummib x (alloc type, context radix tree index),
 numver x version]
```

**Impact**: The per-allocation record changed from `(alloc type, numstackids, numstackids x stackidindex)` to `(alloc type, context radix tree index)`. The stack indices moved from inline arrays to a separate radix tree structure.

---

## 10. Comment-Only Changes (Non-Functional)

### Spelling corrections in comments
Multiple comments were updated to change "synchscope" to "syncscope":
- FUNC_CODE_INST_FENCE (36)
- FUNC_CODE_INST_CMPXCHG_OLD (37)
- FUNC_CODE_INST_ATOMICRMW_OLD (38)
- FUNC_CODE_INST_LOADATOMIC (41)
- FUNC_CODE_INST_STOREATOMIC_OLD (42)
- FUNC_CODE_INST_CMPXCHG (46)
- FUNC_CODE_INST_ATOMICRMW (59)

These are comment-only changes and do not affect parsing.

---

## Implementation Checklist for llvm-pretty-bc-parser

Based on the above enumeration, the following items need to be handled in the bc-parser:

### High Priority (Required for LLVM 22 support)
- [ ] **ATTR_KIND_DEAD_ON_RETURN (103)** - Critical for MSVC STL compatibility
  - Update attribute parsing to recognize code 103
  - Map to appropriate representation in llvm-pretty
  - Handle in function and parameter attribute contexts

- [ ] **Bitcode version check** - Update version acceptance
  - Modify version check to accept LLVM 21 and 22 bitcode

### Medium Priority (Graceful degradation acceptable)
- [ ] **ATTR_KIND_SANITIZE_ALLOC_TOKEN (104)** - Function attribute
  - Add parsing support or skip gracefully with warning

- [ ] **ATTR_KIND_NO_CREATE_UNDEF_OR_POISON (105)** - Function attribute
  - Add parsing support or skip gracefully with warning

- [ ] **FUNC_CODE_DEBUG_RECORD_DECLARE_VALUE (66)** - Debug record
  - Add parsing support or skip gracefully (debug info is often optional)

### Low Priority (Rare in practice)
- [ ] **METADATA_SUBRANGE_TYPE (48)** - Fortran-specific
  - Skip gracefully (only appears in Fortran codebases)

- [ ] **METADATA_FIXED_POINT_TYPE (49)** - Embedded/DSP-specific
  - Skip gracefully (rare in general-purpose code)

- [ ] **CST_CODE_PTRAUTH2 (34)** - ARM64e pointer auth
  - Skip gracefully (only appears on ARM platforms with PAC)

- [ ] **CAST_PTRTOADDR (13)** - New cast operation
  - Add support if encountered in constant expressions

- [ ] **RMW_FMAXIMUM (19) and RMW_FMINIMUM (20)** - Atomic FP ops
  - Add support if encountered in atomic instructions

- [ ] **FS_COMBINED_ALLOC_INFO_NO_CONTEXT (33)** - ThinLTO memprof
  - Skip gracefully (only appears with memory profiling enabled)

- [ ] **FS_COMBINED_CALLSITE_INFO and FS_COMBINED_ALLOC_INFO format changes**
  - Update parsing if ThinLTO summary parsing is implemented
  - Currently these may not be parsed by llvm-pretty-bc-parser

---

## Attribute Details for llvm-pretty

The following attribute information should be added to `llvm-pretty`:

### dead_on_return Attribute
- **Kind code**: 103
- **String representation**: "dead_on_return"
- **Valid contexts**: Parameter
- **Semantic meaning**: The parameter is guaranteed to be dead (will not be accessed) after the function returns normally. This allows optimizations around parameter lifetime.

### sanitize_alloc_token Attribute
- **Kind code**: 104
- **String representation**: "sanitize_alloc_token"
- **Valid contexts**: Function
- **Semantic meaning**: Enables allocation token instrumentation for tracking memory allocations.

### nocreateundeforpoison Attribute
- **Kind code**: 105
- **String representation**: "nocreateundeforpoison"
- **Valid contexts**: Function
- **Semantic meaning**: The function result will not be undef or poison if all arguments are not undef and not poison.

---

## Notes

1. **Backward Compatibility**: LLVM 22 bitcode maintains the same container format as LLVM 20. All changes are additions of new record types or new enum values. No existing record formats were removed or incompatibly changed (except for the FS_COMBINED_* records which are internal to ThinLTO).

2. **Forward Compatibility**: LLVM 20 parsers will fail on LLVM 22 bitcode because:
   - Unknown attribute codes (103-105) will cause errors
   - Version check will reject newer bitcode versions
   - Unknown instruction/metadata codes may cause errors

3. **Testing Strategy**: 
   - Test with MSVC-compiled bitcode to verify `dead_on_return` handling
   - Test with sanitizer-instrumented code for `sanitize_alloc_token`
   - Verify graceful degradation for unimplemented features

4. **Related Work**: This enumeration is a prerequisite for task `saw-script-0dj` which implements the actual parser updates.

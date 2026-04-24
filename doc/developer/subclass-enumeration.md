# Closed-World Subclass Enumeration for Polymorphic Verification

## Status

**Phase**: Design + initial LLVM implementation  
**Issue**: saw-script-ksl

## Problem

SAW verifies polymorphic functions (virtual methods, interface dispatch) against
only one concrete type per `llvm_verify` / `jvm_verify` invocation. Users must
manually identify every subclass, write a separate spec per concrete type, and
call `llvm_verify` once for each. There is no mechanism to automatically discover
and verify against all possible implementations.

This is safe only under closed-world assumptions (the full set of concrete types
is known at link time), which holds for the statically-linked LLVM bitcode and
JVM classpaths that SAW operates on.

## Current State

### LLVM

- `llvm_vtable_slots` (in `SAWCentral.LLVMBuiltins`) walks LLVM module globals
  looking for vtable symbols (`_ZTV` prefix) that match a class name pattern.
  It prints which function occupies each vtable slot.
- No command exists to enumerate **subclasses** of a base class.
- The Itanium C++ ABI stores typeinfo structures as LLVM globals with `_ZTI`
  prefixes. Each typeinfo for a single-inheritance class contains a pointer to
  the parent's typeinfo, forming a linked list from derived → base.

### JVM

- `subclassMap` in `Lang.JVM.Codebase` already builds a `Map ClassName [ClassName]`
  from the loaded class hierarchy.
- `findVirtualMethodsByRef` resolves which concrete method a virtual call
  dispatches to for each subclass.
- Neither is wired into `jvm_verify` for automatic enumeration.

## Proposed Design

### LLVM: RTTI-based hierarchy discovery

#### Data model

The Itanium ABI defines typeinfo globals:

```
@_ZTI7Derived = constant { ptr, ptr, ptr }
  { ptr @_ZTVN10__cxxabiv120__si_class_type_infoE+16,
    ptr @_ZTS7Derived,            ; type name string
    ptr @_ZTI4Base }              ; parent typeinfo pointer
```

Key observations:
- `_ZTI<name>` globals represent typeinfo for class `<name>`.
- Single-inheritance typeinfo (`__si_class_type_info`) has a parent pointer
  at field index 2.
- Virtual-inheritance typeinfo (`__vmi_class_type_info`) stores an array of
  base-class entries (offset + pointer pairs).

#### Algorithm (`llvm_subclasses`)

```
1. Scan LLVM globals for all _ZTI-prefixed symbols.
2. For each typeinfo global, extract:
   a. The class name (demangle from the _ZTI symbol or read the _ZTS string).
   b. The parent typeinfo pointer(s) — resolve through constant expressions.
3. Build a Map from parent → [child] (the inheritance graph).
4. Given a base class name, walk the graph transitively to collect all
   descendants.
5. Return class names as [String].
```

#### New SAWScript commands

| Command | Signature | Description |
|---|---|---|
| `llvm_subclasses` | `LLVMModule -> String -> TopLevel [String]` | Return all concrete subclass names for a base class |

Future commands (not yet implemented):

| Command | Signature | Description |
|---|---|---|
| `llvm_verify_all_subclasses` | `LLVMModule -> String -> (String -> LLVMSetup ()) -> TopLevel [MethodSpec]` | Verify a spec against every subclass |
| `llvm_class_hierarchy` | `LLVMModule -> TopLevel ()` | Print the full inheritance tree |

#### Example usage

```saw
m <- llvm_load_module "program.bc";

// Discover subclasses
subs <- llvm_subclasses m "Shape";
// subs = ["Circle", "Rectangle", "Triangle"]

// Manually verify each (current pattern)
for subs (\cls -> do {
    print (str_concat "Verifying area() for " cls);
    llvm_verify m (str_concat cls "::area") [] false (area_spec cls);
});
```

### JVM: wiring existing infrastructure

The JVM side already has the building blocks:

1. Expose `subclassMap` through a new `jvm_subclasses` command that queries
   the codebase's class hierarchy for a given interface/abstract class.
2. `findVirtualMethodsByRef` already resolves dispatch targets.
3. A `jvm_verify_all_subclasses` command iterates over concrete subclasses,
   calling `jvm_verify` for each with the resolved method reference.

## Implementation Phases

### Phase 1 (this issue)

- [x] Design document (this file)
- [x] `llvm_subclasses` command — parse `_ZTI` globals, build hierarchy, query
- [x] Example SAWScript demonstrating manual subclass verification pattern

### Phase 2 (future)

- [ ] `llvm_verify_all_subclasses` — automatic multi-type verification
- [ ] `llvm_class_hierarchy` — print full tree for debugging
- [ ] Handle `__vmi_class_type_info` (virtual/multiple inheritance)

### Phase 3 (future)

- [ ] `jvm_subclasses` command
- [ ] `jvm_verify_all_subclasses` command
- [ ] Integration tests with multi-class C++ and Java programs

# Parametric Verification with Symbolic Function Pointers

**Issue:** saw-script-i0t  
**Priority:** P4 (Research)

## Problem Statement

Current SAW verification requires concrete function pointer targets.
For polymorphic code that dispatches through function pointers (vtables,
callbacks, strategy patterns), the verifier must enumerate all possible
targets. True parametric verification would allow proving properties
for *any* implementation satisfying a given contract.

## Current State

### LLVM (C++)
- `llvm_bind_method` binds *concrete* implementations to vtable slots
- `llvm_subclasses` enumerates all known subclasses
- Each subclass must be verified individually

### MIR (Rust)
- `mir_bind_method` (new, a4u) binds concrete trait impls
- dyn Trait dispatch is resolved at verification time
- No support for "verify for any impl satisfying trait"

## Research Directions

### Direction 1: Uninterpreted Function Abstraction

Model function pointers as uninterpreted functions with axiomatic specs:

```
∀ f: T → U,  (∀ x: T. precond(x) → postcond(f(x)))
    → property(code_using_f)
```

**Challenges:**
- SAW's memory model ties function pointers to concrete handles
- Need to introduce "abstract" function handles
- Proof obligations become second-order (quantifying over functions)

### Direction 2: Contract-Based Verification

Verify caller assuming *any* implementation satisfying the contract:

```sawscript
// Hypothetical future syntax:
let abstract_method = mir_abstract_spec "Trait::method" trait_contract;
// Verify caller with abstract override
mir_verify m "caller" [abstract_method] false caller_spec z3;
```

The abstract spec would generate universally-quantified constraints.

### Direction 3: Refinement Types

Use Cryptol type-level constraints to parameterize specs:

```cryptol
// Any function satisfying:
type MethodContract a b = a -> b
  where constraint (width a >= 8, width b >= 8)
```

### Direction 4: Behavioral Subtyping (Already Available)

The current `llvm_subclasses` + per-class verification (1od) achieves
a practical form of parametric verification by exhaustive enumeration.
This works when the set of implementations is closed and known.

## Feasibility Assessment

| Approach | Feasibility | Effort | Value |
|----------|-------------|--------|-------|
| Exhaustive enumeration (current) | ✅ Working | Low | High for closed hierarchies |
| Uninterpreted functions | 🟡 Medium | High | High for open extension |
| Contract-based | 🟡 Medium | High | Very high |
| Refinement types | 🔴 Hard | Very high | Research |

## Recommended Path

1. **Short term:** Use exhaustive enumeration (llvm_subclasses, 1od)
2. **Medium term:** Investigate uninterpreted function handles in What4
3. **Long term:** Contract-based parametric verification

## References

- Liskov Substitution Principle verification (1od)
- What4 uninterpreted functions: `What4.Interface.freshTotalUninterpFn`
- SAW's existing `unint` mechanism for keeping terms opaque

# Behavioral Subtyping for Polymorphic Verification

**Issue:** saw-script-1od  
**Status:** Design + Example

## Overview

Behavioral subtyping (Liskov Substitution Principle) states that if `S` is a
subtype of `T`, then objects of type `T` may be replaced with objects of type
`S` without altering any desirable properties. In SAW verification, this means
proving that every derived class satisfies the base class contract.

## Approach

Using existing SAW infrastructure (`llvm_subclasses` + `llvm_verify`), we can
verify behavioral subtyping without any new primitives:

1. Write a **base contract** as a SAWScript function parameterized by class name
2. Use `llvm_subclasses` to discover all concrete subclasses
3. Run `llvm_verify` for each subclass against the base contract
4. Optionally verify **strengthened postconditions** per subclass

## Example: Shape Hierarchy

```cpp
class Shape {
public:
    virtual double area() = 0;       // contract: area() >= 0
    virtual double perimeter() = 0;  // contract: perimeter() >= 0
};

class Circle : public Shape {
    double radius;
public:
    double area() override;          // must satisfy area() >= 0
    double perimeter() override;     // must satisfy perimeter() >= 0
};

class Rectangle : public Shape {
    double width, height;
public:
    double area() override;
    double perimeter() override;
};
```

### SAWScript Verification

```sawscript
enable_experimental;
include "lib/polymorphic_verify.saw";

m <- llvm_load_module "shapes.bc";

// Base contract: area() returns non-negative value
let base_area_spec cls = do {
    this <- llvm_alloc (llvm_alias (str_concat "class." cls));
    llvm_execute_func [this];
    result <- llvm_fresh_var "result" (llvm_double);
    llvm_return (llvm_term result);
    // Liskov: area() >= 0 for ALL subclasses
    llvm_postcond {{ result >= 0.0 }};
};

// Verify base contract holds for every subclass
subs <- llvm_subclasses m "Shape";
for subs (\cls -> do {
    print (str_concat "Checking behavioral subtyping for: " cls);
    let mangled = str_concat "_ZN" (str_concat (show (length cls))
                    (str_concat cls "4areaEv"));
    llvm_verify m mangled [] false (base_area_spec cls) z3;
});

// Strengthened postcondition for Circle (optional, per-subclass)
let circle_area_spec = do {
    this <- llvm_alloc (llvm_alias "class.Circle");
    radius <- llvm_fresh_var "radius" (llvm_double);
    llvm_points_to (llvm_elem this 2) (llvm_term radius);
    llvm_precond {{ radius >= 0.0 }};
    llvm_execute_func [this];
    result <- llvm_fresh_var "result" (llvm_double);
    llvm_return (llvm_term result);
    // Strengthened: area = pi * r^2
    llvm_postcond {{ result == 3.14159265358979 * radius * radius }};
};
```

## Verification Strategy

### Contract Hierarchy

```
Base Contract (must hold for ALL subclasses)
├── Preconditions: may be WEAKENED in subclasses
├── Postconditions: may be STRENGTHENED in subclasses
└── Invariants: must be PRESERVED

Derived Contract (optional, per-subclass refinement)
├── May assume LESS (weaker preconditions)
├── Must guarantee MORE (stronger postconditions)
└── Must maintain base invariants
```

### Steps

1. **Define base contract** as a function of class name
2. **Enumerate subclasses** with `llvm_subclasses`
3. **Verify base contract** for each subclass
4. **Optionally verify strengthened contracts** per subclass
5. **Verify callers** using base contract as override (substitutability)

## Caller Verification (Substitutability)

```sawscript
// Verify code that calls virtual methods through base pointer
let caller_spec = do {
    shape_ptr <- llvm_alloc (llvm_alias "class.Shape");
    llvm_execute_func [shape_ptr];
};

// The base contract overrides are sufficient for callers
caller_ov <- llvm_verify m "process_shape" base_overrides false caller_spec z3;
```

## Limitations

- Requires C++ code compiled with RTTI (`-frtti`)
- Itanium ABI only (MSVC RTTI has different metadata format)
- Virtual destructors and pure virtual functions need special handling
- Multiple inheritance creates more complex typeinfo graph

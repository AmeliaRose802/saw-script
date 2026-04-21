// example.cpp — Demonstrates C++ virtual call devirtualization under LTO.
//
// Compile with:
//   clang++ -std=c++20 -flto -fwhole-program-vtables -fvisibility=hidden \
//           -emit-llvm -c example.cpp -o example.bc
//   llvm-link example.bc -o combined.bc
//   opt -O2 combined.bc -o devirt.bc
//
// After optimization, inspect devirt.bc with `llvm-dis devirt.bc -o devirt.ll`
// to confirm which virtual calls were devirtualized.

#include <cstdint>

// ---------------------------------------------------------------------------
// Base class with a pure virtual method.
// ---------------------------------------------------------------------------
class Transformer {
public:
    virtual uint32_t apply(uint32_t x) const = 0;
    virtual ~Transformer() = default;
};

// ---------------------------------------------------------------------------
// Concrete derived class: doubles its input.
// ---------------------------------------------------------------------------
class Doubler : public Transformer {
public:
    uint32_t apply(uint32_t x) const override {
        return x * 2;
    }
};

// ---------------------------------------------------------------------------
// DEVIRTUALIZED — The optimizer can see that `d` is always a Doubler, so the
// virtual call to apply() is replaced with a direct call (and likely inlined).
// After LTO devirtualization this function reduces to `return x * 2`, which
// SAW can verify.
// ---------------------------------------------------------------------------
extern "C" uint32_t double_concrete(uint32_t x) {
    Doubler d;
    return d.apply(x);
}

// ---------------------------------------------------------------------------
// NOT DEVIRTUALIZED — The concrete type behind `t` is unknown at compile time.
// The optimizer must leave this as an indirect call through the vtable.
// SAW cannot follow indirect calls, so verifying this function requires
// llvm_bind_method (see saw-script-22h).
// ---------------------------------------------------------------------------
extern "C" uint32_t apply_interface(Transformer* t, uint32_t x) {
    return t->apply(x);
}

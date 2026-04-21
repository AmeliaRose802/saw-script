// vtable_dispatch.cpp — Demonstrates SAW verification of C++ virtual dispatch
// using llvm_bind_method.
//
// This models the IsMachineEnabled pattern from MSP's KeyExchangeSession:
// a method that calls through a vtable to an interface method, then makes a
// boolean decision based on the result.
//
// Compile with:
//   clang++ -std=c++20 -O0 -emit-llvm -c vtable_dispatch.cpp -o vtable_dispatch.bc
//
// Or use the provided Makefile.

#include <cstdint>

// ---------------------------------------------------------------------------
// Interface: IKeyStore (pure virtual)
//
// In the real MSP code, GetMachineConfiguration returns a tuple of
// (KeyStoreOperationResult, ParsedConfig).  We simplify to an out-parameter
// for the config and a return value for the operation result.
// ---------------------------------------------------------------------------
class IKeyStore {
public:
    virtual ~IKeyStore() = default;

    // Returns 0 on success, non-zero on failure.
    // On success, writes hostDataEnabled flag to *config_out.
    virtual uint32_t GetMachineConfiguration(
        uint32_t containerId,
        uint32_t* config_out) = 0;
};

// ---------------------------------------------------------------------------
// KeyExchangeSession — holds a pointer to IKeyStore
//
// The vtable pointer for keyStore is at offset 0 of the IKeyStore object.
// GetMachineConfiguration is at vtable slot 1 (slot 0 is the destructor).
// ---------------------------------------------------------------------------
class KeyExchangeSession {
    IKeyStore* keyStore;

public:
    explicit KeyExchangeSession(IKeyStore* ks) : keyStore(ks) {}

    // IsMachineEnabled: the simplest MSP decision function.
    //
    // Calls keyStore->GetMachineConfiguration(containerId, &config)
    // and returns true iff the call succeeded AND the config flag is set.
    //
    // This is the function we verify with SAW using llvm_bind_method
    // to intercept the virtual call to GetMachineConfiguration.
    bool IsMachineEnabled(uint32_t containerId) {
        uint32_t hostDataEnabled = 0;
        uint32_t result = keyStore->GetMachineConfiguration(
            containerId, &hostDataEnabled);
        return (result == 0) && (hostDataEnabled != 0);
    }
};

// ---------------------------------------------------------------------------
// Extern "C" wrapper for SAW verification.
//
// SAW verifies LLVM functions by name.  We wrap IsMachineEnabled in an
// extern "C" function so the symbol name is predictable (no C++ mangling).
// ---------------------------------------------------------------------------
extern "C" uint32_t is_machine_enabled(IKeyStore* keyStore, uint32_t containerId) {
    uint32_t hostDataEnabled = 0;
    uint32_t result = keyStore->GetMachineConfiguration(
        containerId, &hostDataEnabled);
    return (result == 0) && (hostDataEnabled != 0) ? 1 : 0;
}

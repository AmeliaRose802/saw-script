// Simple C++ example with virtual methods for testing llvm_vtable_slots

#include <cstdint>

class IKeyStore {
public:
    virtual ~IKeyStore() = default;
    virtual uint32_t Read() = 0;
    virtual void Latch() = 0;
    virtual uint32_t GetMachineConfiguration() = 0;
};

class ConcreteKeyStore : public IKeyStore {
public:
    uint32_t Read() override { return 42; }
    void Latch() override {}
    uint32_t GetMachineConfiguration() override { return 1; }
};

extern "C" {
    uint32_t test_read(IKeyStore* ks) {
        return ks->Read();
    }
}

#include <stdint.h>

// Simulated vtable structure
typedef struct {
    int32_t (*read)(void *self, uint8_t *buf, uint32_t len);
    int32_t (*write)(void *self, const uint8_t *buf, uint32_t len);
} key_store_vtable;

// Concrete implementation: memory-backed key store
struct mem_key_store {
    const key_store_vtable *vtable;
    uint8_t storage[64];
    uint32_t stored_len;
};

// Concrete read implementation
__attribute__((noinline))
int32_t mem_read(void *self, uint8_t *buf, uint32_t len) {
    struct mem_key_store *ks = (struct mem_key_store *)self;
    if (len > ks->stored_len) return -1;
    for (uint32_t i = 0; i < len; i++) {
        buf[i] = ks->storage[i];
    }
    return 0;
}

// Concrete write implementation
__attribute__((noinline))
int32_t mem_write(void *self, const uint8_t *buf, uint32_t len) {
    struct mem_key_store *ks = (struct mem_key_store *)self;
    if (len > 64) return -1;
    for (uint32_t i = 0; i < len; i++) {
        ks->storage[i] = buf[i];
    }
    ks->stored_len = len;
    return 0;
}

// Vtable instance
const key_store_vtable mem_vtable = { mem_read, mem_write };

// Caller function that uses the vtable
__attribute__((noinline))
int32_t store_and_retrieve(struct mem_key_store *ks,
                           const uint8_t *data, uint32_t data_len,
                           uint8_t *out, uint32_t out_len) {
    int32_t rc = mem_write(ks, data, data_len);
    if (rc != 0) return rc;

    rc = mem_read(ks, out, out_len);
    return rc;
}

#include <stdint.h>
#include <string.h>

// External tracing/logging function
extern void trace_log(const uint8_t *msg, uint64_t len);

// Key material that must NOT leak
struct key_store {
    uint8_t key[32];
    uint64_t key_len;
};

// A function that processes a key but should never log the key bytes
__attribute__((noinline))
int process_key(const struct key_store *ks) {
    // Validate key length
    if (ks->key_len == 0 || ks->key_len > 32) {
        // Log the error (but NOT the key)
        uint8_t err_msg[] = "invalid key length";
        trace_log(err_msg, 18);
        return -1;
    }
    
    // Log that we're processing (but NOT the key content)
    uint8_t info_msg[] = "processing key";
    trace_log(info_msg, 14);
    
    // Do something with the key (placeholder: just check first byte)
    if (ks->key[0] == 0) {
        uint8_t warn_msg[] = "zero key byte";
        trace_log(warn_msg, 13);
        return -2;
    }
    
    return 0;
}

// BAD function: this one DOES leak key material to logs
// (Used as negative test - should fail verification)
__attribute__((noinline))
int process_key_leaky(const struct key_store *ks) {
    // LEAK: logs the actual key bytes!
    trace_log(ks->key, ks->key_len);
    return 0;
}

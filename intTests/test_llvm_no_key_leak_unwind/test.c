#include <stdint.h>

// External functions that may fail
extern int32_t crypto_derive(uint8_t *out, uint32_t out_len,
                              const uint8_t *key, uint32_t key_len);

// Attestation proof buffer
struct attestation_result {
    uint8_t proof[32];
    uint32_t proof_len;
    uint8_t  valid;
};

// Create attestation proof from a key.
// On failure: proof buffer must be zeroed (no partial key material).
__attribute__((noinline))
int32_t create_attestation(const uint8_t *key, uint32_t key_len,
                           struct attestation_result *result) {
    // Initialize output to safe state
    for (uint32_t i = 0; i < 32; i++) {
        result->proof[i] = 0;
    }
    result->proof_len = 0;
    result->valid = 0;
    
    // Attempt key derivation (may fail)
    int32_t rc = crypto_derive(result->proof, 32, key, key_len);
    
    if (rc != 0) {
        // CRITICAL: on failure, zero the proof buffer
        // (may contain partial key material from failed derivation)
        for (uint32_t i = 0; i < 32; i++) {
            result->proof[i] = 0;
        }
        result->proof_len = 0;
        result->valid = 0;
        return -1;
    }
    
    result->proof_len = 32;
    result->valid = 1;
    return 0;
}

#include <stdint.h>

// Key exchange states
#define STATE_INIT        0
#define STATE_KEY_LOADED  1
#define STATE_ATTESTED    2
#define STATE_ERROR       3

struct key_session {
    uint32_t state;
    uint8_t  key_data[32];
    uint32_t key_loaded;
};

// External function that may fail (models allocator/crypto call)
// Returns 0 on success, nonzero on failure
extern int external_crypto_op(uint8_t *out, uint32_t len);

// Attest key ownership: transitions from KEY_LOADED -> ATTESTED
// On failure, must go to ERROR (not stay in intermediate state)
__attribute__((noinline))
int attest_key_ownership(struct key_session *session) {
    // Check precondition: must be in KEY_LOADED state
    if (session->state != STATE_KEY_LOADED) {
        return -1;
    }
    
    // Attempt the crypto operation (may fail)
    uint8_t attestation_proof[32];
    int result = external_crypto_op(attestation_proof, 32);
    
    if (result != 0) {
        // Failure: move to error state (safe)
        session->state = STATE_ERROR;
        return -2;
    }
    
    // Success: transition to attested
    session->state = STATE_ATTESTED;
    return 0;
}

// Load key: transitions from INIT -> KEY_LOADED
// On failure, must stay in INIT or go to ERROR
__attribute__((noinline))
int load_key(struct key_session *session, const uint8_t *key, uint32_t key_len) {
    if (session->state != STATE_INIT) {
        return -1;
    }
    if (key_len > 32) {
        return -1;
    }
    
    // Copy key data
    for (uint32_t i = 0; i < key_len; i++) {
        session->key_data[i] = key[i];
    }
    session->key_loaded = 1;
    session->state = STATE_KEY_LOADED;
    return 0;
}

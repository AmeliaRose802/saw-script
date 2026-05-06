#include <stdint.h>

// --- is_valid_request_date ---
// Validates a date string has correct format: YYYY-MM-DD (10 chars)
// Checks: length == 10, dashes at positions 4 and 7, digits elsewhere
__attribute__((noinline))
uint8_t is_valid_request_date(const uint8_t *data, uint64_t len) {
    if (len != 10) return 0;
    // Check dashes
    if (data[4] != '-' || data[7] != '-') return 0;
    // Check digits (simplified: just check range 0x30-0x39)
    for (int i = 0; i < 10; i++) {
        if (i == 4 || i == 7) continue;  // skip dashes
        if (data[i] < '0' || data[i] > '9') return 0;
    }
    return 1;
}

// --- is_valid_claims_header ---
// Validates claims header is non-empty and starts with '{'
__attribute__((noinline))
uint8_t is_valid_claims_header(const uint8_t *data, uint64_t len) {
    if (len == 0) return 0;
    if (data[0] != '{') return 0;
    return 1;
}

// --- latch_local ---
// Latch operation: if current state is 0 (Unlatched), set to 1 (Latched) and return 0 (Ok)
// If already 1 (Latched), return 1 (AlreadyLatched error)
__attribute__((noinline))
uint8_t latch_local(uint8_t *state) {
    if (*state == 0) {
        *state = 1;
        return 0;  // Ok(Latched)
    }
    return 1;  // Err(AlreadyLatched)
}

// --- latch_key_local ---
// Latch with a key: checks state AND validates key is non-null/non-zero-length
__attribute__((noinline))
uint8_t latch_key_local(uint8_t *state, const uint8_t *key, uint64_t key_len) {
    if (key_len == 0) return 2;  // Err(InvalidKey)
    if (*state == 0) {
        *state = 1;
        return 0;  // Ok(Latched)
    }
    return 1;  // Err(AlreadyLatched)
}

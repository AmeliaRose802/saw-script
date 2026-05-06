#include <stdint.h>

// External allocator that may fail
extern uint8_t* string_alloc(uint64_t size);
extern void string_free(uint8_t* ptr);

// Parse and validate authorization header
// Returns 1 if authorized, 0 if not, -1 on allocation failure
__attribute__((noinline))
int32_t is_valid_authorization(const uint8_t *header, uint64_t header_len) {
    // Need to allocate a buffer to normalize the header
    uint8_t *normalized = string_alloc(header_len + 1);
    if (!normalized) {
        // Allocation failed - MUST return denial, not success
        return -1;
    }
    
    // Copy and normalize (simplified: just copy)
    for (uint64_t i = 0; i < header_len; i++) {
        normalized[i] = header[i];
    }
    normalized[header_len] = 0;
    
    // Check if starts with "HMAC" (simplified check)
    int32_t result = 0;
    if (header_len >= 4 &&
        normalized[0] == 'H' && normalized[1] == 'M' &&
        normalized[2] == 'A' && normalized[3] == 'C') {
        result = 1;
    }
    
    string_free(normalized);
    return result;
}

// Wrapper that must always return 0 or 1 (never -1)
__attribute__((noinline))
uint8_t check_authorization(const uint8_t *header, uint64_t header_len) {
    int32_t result = is_valid_authorization(header, header_len);
    // Any error (including alloc failure) means unauthorized
    if (result <= 0) return 0;
    return 1;
}

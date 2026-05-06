#include <stdint.h>
#include <stddef.h>

// Case-insensitive comparison for ASCII
static inline uint8_t to_lower(uint8_t c) {
    return (c >= 'A' && c <= 'Z') ? (c + 32) : c;
}

// Validate metadata header: check if value is "true" (case-insensitive)
// Represents Rust is_valid_metadata_header pattern
__attribute__((noinline))
uint8_t is_valid_metadata_header(const uint8_t *data, uint64_t len) {
    if (len != 4) return 0;
    if (to_lower(data[0]) != 't') return 0;
    if (to_lower(data[1]) != 'r') return 0;
    if (to_lower(data[2]) != 'u') return 0;
    if (to_lower(data[3]) != 'e') return 0;
    return 1;
}

// A caller function that uses the header validation
// This would previously use llvm_unsafe_assume_spec
__attribute__((noinline))
uint8_t process_request(const uint8_t *header_value, uint64_t header_len,
                        const uint8_t *payload, uint64_t payload_len) {
    // First validate the metadata header
    if (!is_valid_metadata_header(header_value, header_len)) {
        return 0;  // reject
    }
    // If valid, proceed (simplified: just return 1)
    return 1;
}

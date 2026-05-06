#include <stdint.h>

struct token {
    uint64_t start;
    uint64_t len;
};

// Parse an authorization header: "HMAC-SHA256 <key-guid> <hex-hmac>"
// Split by spaces into up to 3 tokens.
// Returns number of tokens found (should be 3 for valid header).
__attribute__((noinline))
uint32_t parse_auth_header(const uint8_t *data, uint64_t data_len,
                           struct token *tokens, uint32_t max_tokens) {
    if (max_tokens == 0) return 0;
    
    uint32_t count = 0;
    uint64_t i = 0;
    
    // Skip leading spaces
    while (i < data_len && data[i] == ' ') i++;
    
    while (i < data_len && count < max_tokens) {
        // Start of token
        tokens[count].start = i;
        
        // Find end of token
        uint64_t start = i;
        while (i < data_len && data[i] != ' ') i++;
        
        tokens[count].len = i - start;
        count++;
        
        // Skip spaces between tokens
        while (i < data_len && data[i] == ' ') i++;
    }
    
    return count;
}

// Validate that the auth scheme (first token) is "HMAC-SHA256"
// Returns 1 if valid, 0 if not
__attribute__((noinline))
uint8_t validate_auth_scheme(const uint8_t *header, uint64_t header_len) {
    // Expected scheme
    const uint8_t expected[] = "HMAC-SHA256";
    const uint64_t expected_len = 11;
    
    struct token tokens[3];
    uint32_t count = parse_auth_header(header, header_len, tokens, 3);
    
    // Must have exactly 3 tokens
    if (count != 3) return 0;
    
    // First token must match "HMAC-SHA256"
    if (tokens[0].len != expected_len) return 0;
    
    for (uint64_t i = 0; i < expected_len; i++) {
        if (header[tokens[0].start + i] != expected[i]) return 0;
    }
    
    return 1;
}

#include <stdint.h>

// External function: could be OpenSSL, OS call, etc.
// We model it as completely unspecified.
extern int32_t external_encrypt(uint8_t *output, uint64_t out_len,
                                 const uint8_t *input, uint64_t in_len);

// Caller that must be correct regardless of what external_encrypt does
__attribute__((noinline))
int32_t safe_encrypt(uint8_t *output, uint64_t out_len,
                     const uint8_t *input, uint64_t in_len) {
    // Pre-validate arguments
    if (out_len < in_len) return -1;
    if (in_len == 0) return -2;
    if (out_len > 1024) return -3;

    // Call external function
    int32_t result = external_encrypt(output, out_len, input, in_len);

    // Post-check: regardless of what external_encrypt did,
    // we report its result code faithfully
    if (result != 0) return result;

    return 0;
}

// Another caller that uses the result defensively
__attribute__((noinline))
int32_t defensive_caller(uint8_t *buf, uint64_t buf_len,
                         const uint8_t *data, uint64_t data_len) {
    if (buf_len == 0 || data_len == 0) return -1;
    if (buf_len > 1024 || data_len > 1024) return -1;
    if (buf_len < data_len) return -1;

    int32_t rc = external_encrypt(buf, buf_len, data, data_len);

    // Defensive: always return a bounded value
    if (rc < -100) return -100;
    if (rc > 100) return 100;
    return rc;
}

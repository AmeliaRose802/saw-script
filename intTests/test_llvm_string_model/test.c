#include <stdint.h>
#include <string.h>

// Simulate MSVC string layout: [16 x i8] + i64 size + i64 capacity
struct msvc_string {
    char buf[16];
    uint64_t size;
    uint64_t capacity;
};

// Simple "size" function
__attribute__((noinline))
uint64_t string_size(const struct msvc_string *s) {
    return s->size;
}

// Simple "compare" - lexicographic on the SSO buffers (for small strings)
__attribute__((noinline))
int string_compare(const struct msvc_string *a, const struct msvc_string *b) {
    uint64_t min_len = a->size < b->size ? a->size : b->size;
    for (uint64_t i = 0; i < min_len && i < 16; i++) {
        if ((unsigned char)a->buf[i] < (unsigned char)b->buf[i]) return -1;
        if ((unsigned char)a->buf[i] > (unsigned char)b->buf[i]) return 1;
    }
    if (a->size < b->size) return -1;
    if (a->size > b->size) return 1;
    return 0;
}

// Simple "equal" check for small strings
__attribute__((noinline))
int string_equal(const struct msvc_string *a, const struct msvc_string *b) {
    if (a->size != b->size) return 0;
    for (uint64_t i = 0; i < a->size && i < 16; i++) {
        if (a->buf[i] != b->buf[i]) return 0;
    }
    return 1;
}

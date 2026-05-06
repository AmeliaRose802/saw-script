#include <stdint.h>

struct string8 {
    uint8_t content[8];
    uint64_t len;
};

__attribute__((noinline))
int32_t str_compare(const struct string8 *a, const struct string8 *b) {
    uint64_t min_len = a->len < b->len ? a->len : b->len;
    for (uint64_t i = 0; i < min_len; i++) {
        if (a->content[i] < b->content[i]) return -1;
        if (a->content[i] > b->content[i]) return 1;
    }
    if (a->len < b->len) return -1;
    if (a->len > b->len) return 1;
    return 0;
}

__attribute__((noinline))
uint8_t str_equal(const struct string8 *a, const struct string8 *b) {
    if (a->len != b->len) return 0;
    for (uint64_t i = 0; i < a->len; i++) {
        if (a->content[i] != b->content[i]) return 0;
    }
    return 1;
}

__attribute__((noinline))
void str_substr(struct string8 *result, const struct string8 *src,
                uint64_t pos, uint64_t count) {
    uint64_t actual_pos = pos > src->len ? src->len : pos;
    uint64_t remaining = src->len - actual_pos;
    uint64_t actual_count = count > remaining ? remaining : count;

    for (uint64_t i = 0; i < actual_count; i++) {
        result->content[i] = src->content[actual_pos + i];
    }
    for (uint64_t i = actual_count; i < 8; i++) {
        result->content[i] = 0;
    }
    result->len = actual_count;
}

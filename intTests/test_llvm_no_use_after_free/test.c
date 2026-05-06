#include <stdint.h>

// Models for heap operations
extern void* model_alloc(uint64_t size);
extern void model_free(void* ptr);

// A key buffer that must be safely cleaned up
struct key_buffer {
    uint8_t *data;
    uint64_t len;
    uint8_t  is_allocated;
};

// Initialize a key buffer (may fail)
// Returns 0 on success, -1 on failure
__attribute__((noinline))
int key_buffer_init(struct key_buffer *buf, uint64_t size) {
    buf->data = (uint8_t*)model_alloc(size);
    if (!buf->data) {
        buf->is_allocated = 0;
        buf->len = 0;
        return -1;
    }
    buf->is_allocated = 1;
    buf->len = size;
    return 0;
}

// Free a key buffer (only if allocated)
__attribute__((noinline))
void key_buffer_free(struct key_buffer *buf) {
    if (buf->is_allocated) {
        model_free(buf->data);
        buf->data = (void*)0;
        buf->is_allocated = 0;
        buf->len = 0;
    }
}

// Process that creates a temporary buffer, may fail mid-operation,
// and must clean up properly on all paths
__attribute__((noinline))
int process_with_cleanup(uint64_t key_size) {
    struct key_buffer temp;
    temp.data = (void*)0;
    temp.is_allocated = 0;
    temp.len = 0;
    
    // Attempt allocation
    int rc = key_buffer_init(&temp, key_size);
    if (rc != 0) {
        // Allocation failed - no cleanup needed
        // key_buffer_free is safe to call (checks is_allocated)
        key_buffer_free(&temp);
        return -1;
    }
    
    // Use the buffer (write first byte)
    temp.data[0] = 0x42;
    
    // Clean up
    key_buffer_free(&temp);
    return 0;
}

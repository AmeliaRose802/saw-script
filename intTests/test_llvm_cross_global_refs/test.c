#include <stdint.h>

// Global array (const so SAW auto-populates during module init)
const int32_t lookup_table[4] = {100, 200, 300, 400};

// Cross-global pointer reference: const ptr initialized to address of lookup_table[2]
// This exercises populateRec: table_ptr's initializer contains a GEP into lookup_table,
// so lookup_table must be recursively populated before table_ptr can be evaluated.
int32_t * const table_ptr = (int32_t *)&lookup_table[2];

// A struct with a pointer to another global
struct config {
    int32_t version;
    const int32_t *data;
};

const int32_t secondary_data = 42;

// Cross-global struct reference: global_config.data points to secondary_data
const struct config global_config = { .version = 1, .data = &secondary_data };

// Function that reads through the cross-global pointer
__attribute__((noinline))
int32_t read_via_global_ptr(void) {
    return *table_ptr;
}

// Function that reads from the config struct's cross-global pointer
__attribute__((noinline))
int32_t read_config_data(void) {
    return *global_config.data;
}

// Function that uses both globals together
__attribute__((noinline))
int32_t read_both(void) {
    return *table_ptr + *global_config.data;
}

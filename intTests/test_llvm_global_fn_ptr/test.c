#include <stdint.h>

// A function pointer type
typedef uint32_t (*operation_fn)(uint32_t, uint32_t);

// Functions that exist in the module
__attribute__((noinline))
uint32_t add_op(uint32_t a, uint32_t b) {
    return a + b;
}

__attribute__((noinline))
uint32_t mul_op(uint32_t a, uint32_t b) {
    return a * b;
}

// Global function pointer table (all functions present)
const operation_fn op_table[2] = { add_op, mul_op };

// Function that dispatches through the table
__attribute__((noinline))
uint32_t dispatch(uint32_t op_idx, uint32_t a, uint32_t b) {
    if (op_idx > 1) return 0;
    return op_table[op_idx](a, b);
}

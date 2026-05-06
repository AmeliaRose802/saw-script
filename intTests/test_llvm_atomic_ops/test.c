#include <stdatomic.h>

__attribute__((noinline))
int atomic_counter(_Atomic(int) *ptr, int val) {
    return atomic_fetch_add(ptr, val);
}

__attribute__((noinline))
int atomic_cas(_Atomic(int) *ptr, int expected, int desired) {
    return atomic_compare_exchange_strong(ptr, &expected, desired) ? 1 : 0;
}

__attribute__((noinline))
int atomic_xchg(_Atomic(int) *ptr, int newval) {
    return atomic_exchange(ptr, newval);
}

/*
    Compability header for stdatomic.h that works for all compilers supported
    by V. For TCC libatomic from the operating system is used

*/
#ifndef __ATOMIC_H
#define __ATOMIC_H

#ifndef __cplusplus
// If C just use stdatomic.h
#ifndef __TINYC__
#include <stdatomic.h>
#endif
#else
// CPP wrapper for atomic operations that are compatible with C
#include "atomic_cpp.h"
#endif

#ifdef __TINYC__

typedef volatile intptr_t atomic_llong;
typedef volatile intptr_t atomic_ullong;
typedef volatile intptr_t atomic_uintptr_t;

// use functions for 64 bit types (8 bytes) from libatomic directly
// since tcc is not capible to use "generics" in C

extern intptr_t __atomic_load_8(intptr_t* x, int mo);
extern intptr_t __atomic_store_8(intptr_t* x, intptr_t y, int mo);
extern char __atomic_compare_exchange_8(intptr_t* x, intptr_t* expected, intptr_t y, int mo);
extern char __atomic_compare_exchange_8(intptr_t* x, intptr_t* expected, intptr_t y, int mo);
extern intptr_t __atomic_exchange_8(intptr_t* x, intptr_t y, int mo);
extern intptr_t __atomic_fetch_add_8(intptr_t* x, intptr_t y, int mo);
extern intptr_t __atomic_fetch_sub_8(intptr_t* x, intptr_t y, int mo);

#define atomic_load_explicit __atomic_load_8
#define atomic_store_explicit __atomic_store_8
#define atomic_compare_exchange_weak_explicit __atomic_compare_exchange_8
#define atomic_compare_exchange_strong_explicit __atomic_compare_exchange_8
#define atomic_exchange_explicit __atomic_exchange_8
#define atomic_fetch_add_explicit __atomic_fetch_add_8
#define atomic_fetch_sub_explicit __atomic_sub_fetch_8

#define memory_order_relaxed 0
#define memory_order_consume 1
#define memory_order_acquire 2
#define memory_order_release 3
#define memory_order_acq_rel 4
#define memory_order_seq_cst 5

static inline intptr_t atomic_load(intptr_t* x) {
	return atomic_load_explicit(x, memory_order_seq_cst);
}
static inline intptr_t atomic_store(intptr_t* x, intptr_t y) {
	return atomic_store_explicit(x, y, memory_order_seq_cst);
}
static inline int atomic_compare_exchange_weak(intptr_t* x, intptr_t* expected, intptr_t y) {
	return atomic_compare_exchange_weak_explicit(x, expected, y, memory_order_seq_cst);
}
static inline int atomic_compare_exchange_strong(intptr_t* x, intptr_t* expected, intptr_t y) {
	return atomic_compare_exchange_strong_explicit(x, expected, y, memory_order_seq_cst);
}
static inline intptr_t atomic_exchange(intptr_t* x, intptr_t y) {
	return atomic_exchange_explicit(x, y, memory_order_seq_cst);
}
static inline intptr_t atomic_fetch_add(intptr_t* x, intptr_t y) {
	return atomic_fetch_add_explicit(x, y, memory_order_seq_cst);
}
static inline intptr_t atomic_fetch_sub(intptr_t* x, intptr_t y) {
	return atomic_fetch_sub_explicit(x, y, memory_order_seq_cst);
}

#endif
#endif

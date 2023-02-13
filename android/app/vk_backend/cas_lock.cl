static void lock(global atomic_uint* l) {
    uint e, acq;
    atomic_work_item_fence(CLK_GLOBAL_MEM_FENCE, memory_order_release, memory_scope_device);
    e = 0;
    acq = 0;
    while (acq == 0) {
        acq = atomic_compare_exchange_strong_explicit(l, &e, 1, memory_order_acquire, memory_order_relaxed);
        e = 0;
    }
}

static void unlock(global atomic_uint* l) {
    atomic_store_explicit(l, 0, memory_order_release);
}

kernel void lock_test(global atomic_uint* l, global uint* res, global uint* iters) {
    uint x;
    for (uint i = 0; i < *iters; i++) {
        lock(l);

        x = *res;
        x++;
        *res = x;

        unlock(l);

    }
}

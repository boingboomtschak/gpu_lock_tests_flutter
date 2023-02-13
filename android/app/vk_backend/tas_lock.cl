static void lock(global atomic_uint* l) {
    atomic_work_item_fence(CLK_GLOBAL_MEM_FENCE, memory_order_release, memory_scope_device);
    while (atomic_exchange_explicit(l, 1, memory_order_acquire));
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

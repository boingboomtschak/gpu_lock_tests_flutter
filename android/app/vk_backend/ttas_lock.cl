static void lock(global atomic_uint* l) {
    while(1) {
        while(atomic_load_explicit(l, memory_order_acquire));
        if (!atomic_exchange_explicit(l, 1, memory_order_acquire))
            return;
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

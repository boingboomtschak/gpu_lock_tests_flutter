static void lock(global atomic_uint* l) {
    uint e = 0;
    uint acq = 0;
    while (acq == 0) {
        acq = atomic_compare_exchange_strong_explicit(l, &e, 1, memory_order_relaxed, memory_order_relaxed);
        e = 0;
    }
    atomic_work_item_fence(CLK_GLOBAL_MEM_FENCE, memory_order_acquire, memory_scope_device);

}

static void unlock(global atomic_uint* l) {
    atomic_work_item_fence(CLK_GLOBAL_MEM_FENCE, memory_order_release, memory_scope_device);
    atomic_store_explicit(l, 0, memory_order_relaxed);
}

kernel void lock_test(global atomic_uint* l, global uint* res, global uint* iters, global uint* garbage) {
//    if (get_local_id(0) != 0) {
//        for (uint j = 0; j < *iters; j++) {
//            uint i = get_group_id(0) * get_local_id(0);
//            uint x = garbage[i];
//            x += get_local_id(0);
//            garbage[i] = x;
//        }
//    } else {
      if (get_local_id(0) == 0) {
        for (uint i = 0; i < *iters; i++) {
            lock(l);

            uint x = *res;
            x++;
            *res = x;

            unlock(l);
        }
    }
}
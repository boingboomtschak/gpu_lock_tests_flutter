static void lock(global atomic_uint* l) {
    while(1) {
        while(atomic_load_explicit(l, memory_order_relaxed));
        if (!atomic_exchange_explicit(l, 1, memory_order_relaxed)) {
            atomic_work_item_fence(CLK_GLOBAL_MEM_FENCE, memory_order_acquire, memory_scope_device);
            return;
        }
    }
}

static void unlock(global atomic_uint* l) {
    atomic_work_item_fence(CLK_GLOBAL_MEM_FENCE, memory_order_release, memory_scope_device);
    atomic_store_explicit(l, 0, memory_order_relaxed);
}

kernel void lock_test(global atomic_uint* l, global uint* res, global uint* iters, global uint* garbage) {
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

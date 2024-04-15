// Copyright 2020 ETH Zurich
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#pragma once

#include <hal/pulp.h>

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "spin_conf.h"

#include "pspin_rt.h"

#define MEM_ALIGNMENT 4
#define ALIGN_UP(NUM, ALIGN) ((((uint32_t)(NUM)) + ((ALIGN)-1)) & ~((ALIGN)-1))
#define DMA_MAX_XFER_SIZE 32768
#define DMA_NULL 0

typedef uint32_t dma_t;
typedef volatile uint32_t futex_t;

// definition in link.ld
#define MAX_COUNTERS 16

struct perf_counter {
  uint32_t sum;
  uint32_t count;
};

struct host_data {
  uint64_t flag[CORE_COUNT];
  struct perf_counter counters[MAX_COUNTERS];
};
extern volatile struct host_data __host_data;

#ifndef NO_PULP

static inline void rt_time_wait_cycles(const unsigned cycles) {
  /**
   * Each iteration of the loop below will take four cycles on RI5CY (one for
   * `addi` and three for the taken `bnez`; if the instructions hit in the
   * I$).  Thus, we let `i` count the number of remaining loop iterations and
   * initialize it to a fourth of the number of clock cyles.  With this
   * initialization, we must not enter the loop if the number of clock cycles
   * is less than four, because this will cause an underflow on the first
   * subtraction.
   */
  register unsigned threshold;
  asm volatile("li %[threshold], 4" : [ threshold ] "=r"(threshold));
  asm volatile goto("ble %[cycles], %[threshold], %l2"
                    : /* no output */
                    : [ cycles ] "r"(cycles), [ threshold ] "r"(threshold)
                    : /* no clobbers */
                    : __wait_cycles_end);
  register unsigned i = cycles >> 2;
__wait_cycles_start:
  // Decrement `i` and loop if it is not yet zero.
  asm volatile("addi %0, %0, -1" : "+r"(i));
  asm volatile goto("bnez %0, %l1"
                    : /* no output */
                    : "r"(i)
                    : /* no clobbers */
                    : __wait_cycles_start);
__wait_cycles_end:
  return;
}

static inline void asm_mem_fence() { __asm__ __volatile__("" : : : "memory"); }

static inline uint32_t load_reserved(volatile const uint32_t *const addr) {
  uint32_t val;
  asm_mem_fence();
  asm volatile("lr.w %0, (%1)" : "=r"(val) : "r"(addr));
  asm_mem_fence();
  return val;
}

/**
 * Expose the store-conditional instruction.  Only stores a value if a
 * previously made reservation has not been broken.
 *
 * @param   addr    A pointer to L2 memory at which to store the value.
 * @param   val     Value to store.
 *
 * @return  0:  Store was successful (the reservation was still valid).
 *          1:  Reservation was broken, no store happened.
 *          2:  Slave error; the slave does not support LR/SC.
 *          3:  The address does not exist.
 */
static inline unsigned store_conditional(volatile uint32_t *const addr,
                                         const uint32_t val) {
  unsigned res;
  asm_mem_fence();
  asm volatile("sc.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

/**
 * Swap a value atomically if the old memory value matches.
 *
 * @param   addr    A pointer to L2 memory at which to swap the value.
 * @param   old     The value expected in memory.
 * @param   new     The new value to be stored if `old` matches the memory
 * content.
 *
 * @return   0: Swap was successful.
 *          -1: No swap because old value did not match.
 *          >0: No swap because atomic access failed.
 */
static inline int compare_and_swap(volatile uint32_t *const addr,
                                   const uint32_t old, const uint32_t new) {
  uint32_t tmp = load_reserved(addr);
  if (tmp == old)
    return store_conditional(addr, new);
  else
    return -1;
}

static inline uint32_t amo_swap(volatile uint32_t *const addr,
                                const uint32_t val) {
  uint32_t res;
  asm_mem_fence();
  asm volatile("amoswap.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static inline void amo_store(volatile uint32_t *const addr,
                             const uint32_t val) {
  asm_mem_fence();
  asm volatile("amoswap.w x0, %0, (%1)" : : "r"(val), "r"(addr));
  asm_mem_fence();
}

static inline int32_t amo_add(volatile int32_t *const addr, const int32_t val) {
  int32_t res;
  asm_mem_fence();
  asm volatile("amoadd.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static inline uint32_t amo_and(volatile uint32_t *const addr,
                               const uint32_t val) {
  uint32_t res;
  asm_mem_fence();
  asm volatile("amoand.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static inline uint32_t amo_or(volatile uint32_t *const addr,
                              const uint32_t val) {
  uint32_t res;
  asm_mem_fence();
  asm volatile("amoor.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static inline uint32_t amo_xor(volatile uint32_t *const addr,
                               const uint32_t val) {
  uint32_t res;
  asm_mem_fence();
  asm volatile("amoxor.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static inline uint32_t amo_maxu(volatile uint32_t *const addr,
                                const uint32_t val) {
  uint32_t res;
  asm_mem_fence();
  asm volatile("amomaxu.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static inline int32_t amo_max(volatile int32_t *const addr, const int32_t val) {
  int32_t res;
  asm_mem_fence();
  asm volatile("amomax.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static inline uint32_t amo_minu(volatile uint32_t *const addr,
                                const uint32_t val) {
  uint32_t res;
  asm_mem_fence();
  asm volatile("amominu.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static inline int32_t amo_min(volatile int32_t *const addr, const int32_t val) {
  int32_t res;
  asm_mem_fence();
  asm volatile("amomin.w %0, %1, (%2)" : "=r"(res) : "r"(val), "r"(addr));
  asm_mem_fence();
  return res;
}

static void futex_init(futex_t *futex) {
  //*futex = 0;
  amo_store(futex, 0);
}

static inline int futex_try_lock(futex_t *futex) {
  return amo_or(futex, 1) == 0;
}

static inline int futex_lock(futex_t *futex) {
  while (amo_or(futex, 1)) {
    ;
  }
  return 1;
}

static inline int futex_lock_s(futex_t *futex) {
  while (amo_or(futex, 1)) {
    rt_time_wait_cycles(32);
  }
  return 1;
}

static inline void futex_unlock(futex_t *futex) { futex_init(futex); }

static inline uint32_t cycles() {
  uint32_t c;
  ecall_0(PSPIN_ECALL_CYCLES, c);
  return c;
}

static inline void push_counter(volatile struct perf_counter *c, uint32_t dur) {
  amo_add(&c->count, 1);
  amo_add(&c->sum, dur);
}

#endif
/*
 * Configuration for umm_malloc - DO NOT EDIT THIS FILE BY HAND!
 *
 * NOTE WELL: Your project MUST have a umm_malloc_cfgport.h - even if
 *            it's empty!!!
 *
 * Refer to the notes below for details on the umm_malloc configuration
 * options.
 */

#ifndef _UMM_MALLOC_CFG_H
#define _UMM_MALLOC_CFG_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

/*
 * There are a number of defines you can set at compile time that affect how
 * the memory allocator will operate.
 *
 * You should NOT edit this file, it may be changed from time to time in
 * the upstream project. Instead, you can do one of the following (in order
 * of priority
 *
 * 1. Pass in the override values on the command line using -D UMM_xxx
 * 2. Pass in the filename holding override values using -D UMM_CFGFILE
 * 3. Set up defaults in a file called umm_malloc_cfgport.h
 *
 * NOTE WELL: For the command line -D options to take highest priority, your
 *            project level override file must check that the UMM_xxx
 *            value is not already defined before overriding
 *
 * Unless otherwise noted, the default state of these values is #undef-ined!
 *
 * As this is the top level configuration file, it is responsible for making
 * sure that the configuration makes sense. For example the UMM_BLOCK_BODY_SIZE
 * is a minimum of 8 and a multiple of 4.
 *
 * UMM_BLOCK_BODY_SIZE
 *
 * Defines the umm_block[].body size - it is 8 by default
 *
 * This assumes umm_ptr is a pair of uint16_t values
 * which is 4 bytes plus the data[] array which is another 4 bytes
 * for a total of 8.
 *
 * NOTE WELL that the umm_block[].body size must be multiple of
 *           the natural access size of the host machine to ensure
 *           that accesses are efficient.
 *
 *           We have not verified the checks below for 64 bit machines
 *           because this library is targeted for 32 bit machines.
 *
 * UMM_NUM_HEAPS
 *
 * Set to the maximum number of heaps that can be defined by the
 * application - defaults to 1.
 *
 * UMM_BEST_FIT (default)
 *
 * Set this if you want to use a best-fit algorithm for allocating new blocks.
 * On by default, turned off by UMM_FIRST_FIT
 *
 * UMM_FIRST_FIT
 *
 * Set this if you want to use a first-fit algorithm for allocating new blocks.
 * Faster than UMM_BEST_FIT but can result in higher fragmentation.
 *
 * UMM_INFO
 *
 * Set if you want the ability to calculate metrics on demand
 *
 * UMM_INLINE_METRICS
 *
 * Set this if you want to have access to a minimal set of heap metrics that
 * can be used to gauge heap health.
 * Setting this at compile time will automatically set UMM_INFO.
 * Note that enabling this define will add a slight runtime penalty.
 *
 * UMM_CHECK_INITIALIZED
 *
 * Set if you want to be able to verify that the heap is intialized
 * before any operation - the default is no check. You may set the
 * UMM_CHECK_INITIALIZED macro to the following provided macros, or
 * write your own handler:
 *
 *    UMM_INIT_IF_UNINITIALIZED
 *    UMM_HANG_IF_UNINITIALIZED
 *
 * UMM_INTEGRITY_CHECK
 *
 * Set if you want to be able to verify that the heap is semantically correct
 * before or after any heap operation - all of the block indexes in the heap
 * make sense.
 * Slows execution dramatically but catches errors really quickly.
 *
 * UMM_POISON_CHECK
 *
 * Set if you want to be able to leave a poison buffer around each allocation.
 * Note this uses an extra 8 bytes per allocation, but you get the benefit of
 * being able to detect if your program is writing past an allocated buffer.
 *
 * DBGLOG_ENABLE
 *
 * Set if you want to enable logging - the default is to use printf() but
 * if you have any special requirements such as thread safety or a custom
 * logging routine - you are free to everride the default
 *
 * DBGLOG_LEVEL=n
 *
 * Set n to a value from 0 to 6 depending on how verbose you want the debug
 * log to be
 *
 * UMM_MAX_CRITICAL_DEPTH_CHECK=n
 *
 * Set this if you want to compile in code to verify that the critical
 * section maximum depth is not exceeded. If set, the value must be greater
 * than 0.
 *
 * The critical depth checking is only needed if your target environment
 * does not support reading and writing the current interrupt enable state.
 *
 * Support for this library in a multitasking environment is provided when
 * you add bodies to the UMM_CRITICAL_ENTRY and UMM_CRITICAL_EXIT macros
 * (see below)
 *
 * ----------------------------------------------------------------------------
 */

#ifdef UMM_CFGFILE
#include UMM_CFGFILE
#else
#include <umm_malloc_cfgport.h>
#endif

/* Forward declaration of umm_heap_config */
struct umm_heap_config;

/* A couple of macros to make packing structures less compiler dependent */

#ifndef UMM_H_ATTPACKPRE
    #define UMM_H_ATTPACKPRE
#endif
#ifndef UMM_H_ATTPACKSUF
    #define UMM_H_ATTPACKSUF __attribute__((__packed__))
#endif

/* -------------------------------------------------------------------------- */

#ifndef UMM_INIT_IF_UNINITIALIZED
    #define UMM_INIT_IF_UNINITIALIZED() do { if (UMM_HEAP == NULL) { umm_init(); } } while(0)
#endif

#ifndef UMM_HANG_IF_UNINITIALIZED
    #define UMM_HANG_IF_UNINITIALIZED() do { if (UMM_HEAP == NULL) { while(1) {} } } while(0)
#endif

#ifndef UMM_CHECK_INITIALIZED
    #define UMM_CHECK_INITIALIZED()
#endif

/* -------------------------------------------------------------------------- */

#ifndef UMM_BLOCK_BODY_SIZE
    #define UMM_BLOCK_BODY_SIZE (8)
#endif

#define UMM_MIN_BLOCK_BODY_SIZE (8)

#if (UMM_BLOCK_BODY_SIZE < UMM_MIN_BLOCK_BODY_SIZE)
    #error UMM_BLOCK_BODY_SIZE must be at least 8!
#endif

#if ((UMM_BLOCK_BODY_SIZE % 4) != 0)
    #error UMM_BLOCK_BODY_SIZE must be multiple of 4!
#endif

/* -------------------------------------------------------------------------- */

#ifndef UMM_NUM_HEAPS
    #define UMM_NUM_HEAPS (1)
#endif

#if (UMM_NUM_HEAPS < 1)
    #error UMM_NUM_HEAPS must be at least 1!
#endif

/* -------------------------------------------------------------------------- */

#ifdef UMM_BEST_FIT
  #ifdef  UMM_FIRST_FIT
    #error Both UMM_BEST_FIT and UMM_FIRST_FIT are defined - pick one!
  #endif
#else /* UMM_BEST_FIT is not defined */
  #ifndef UMM_FIRST_FIT
    #define UMM_BEST_FIT
  #endif
#endif

/* -------------------------------------------------------------------------- */

#ifdef UMM_INLINE_METRICS
  #define UMM_MULTI_FRAGMENTATION_METRIC_INIT(h) umm_multi_fragmentation_metric_init(h)
  #define UMM_MULTI_FRAGMENTATION_METRIC_ADD(h,c) umm_multi_fragmentation_metric_add(h,c)
  #define UMM_MULTI_FRAGMENTATION_METRIC_REMOVE(h,c) umm_multi_fragmentation_metric_remove(h,c)
  #define UMM_FRAGMENTATION_METRIC_INIT() umm_fragmentation_metric_init()
  #define UMM_FRAGMENTATION_METRIC_ADD(c) umm_fragmentation_metric_add(c)
  #define UMM_FRAGMENTATION_METRIC_REMOVE(c) umm_fragmentation_metric_remove(c)
  #ifndef UMM_INFO
  #define UMM_INFO
  #endif
#else
  #define UMM_FRAGMENTATION_METRIC_INIT()
  #define UMM_FRAGMENTATION_METRIC_ADD(c)
  #define UMM_FRAGMENTATION_METRIC_REMOVE(c)
#endif // UMM_INLINE_METRICS

/* -------------------------------------------------------------------------- */

#ifdef UMM_INFO
typedef struct UMM_HEAP_INFO_t {
    unsigned int totalEntries;
    unsigned int usedEntries;
    unsigned int freeEntries;

    unsigned int totalBlocks;
    unsigned int usedBlocks;
    unsigned int freeBlocks;
    unsigned int freeBlocksSquared;

    unsigned int maxFreeContiguousBlocks;

    int usage_metric;
    int fragmentation_metric;
}
UMM_HEAP_INFO;

extern UMM_HEAP_INFO ummHeapInfo;

extern void *umm_multi_info(struct umm_heap_config *heap, void *ptr, bool force);
extern size_t umm_multi_free_heap_size(struct umm_heap_config *heap);
extern size_t umm_multi_max_free_block_size(struct umm_heap_config *heap);
extern int umm_multi_usage_metric(struct umm_heap_config *heap);
extern int umm_multi_fragmentation_metric(struct umm_heap_config *heap);
extern void *umm_info(void *ptr, bool force);
extern size_t umm_free_heap_size(void);
extern size_t umm_max_free_block_size(void);
extern int umm_usage_metric(void);
extern int umm_fragmentation_metric(void);
#else
  #define umm_multi_info(h,p,b)
  #define umm_multi_free_heap_size(h) (0)
  #define umm_multi_max_free_block_size(h) (0)
  #define umm_multi_usage_metric(h) (0)
  #define umm_multi_fragmentation_metric(h) (0)
  #define umm_info(p,b)
  #define umm_free_heap_size() (0)
  #define umm_max_free_block_size() (0)
  #define umm_usage_metric() (0)
  #define umm_fragmentation_metric() (0)
#endif

/*
 * Three macros to make it easier to protect the memory allocator in a
 * multitasking system. You should set these macros up to use whatever your
 * system uses for this purpose. You can disable interrupts entirely, or just
 * disable task switching - it's up to you
 *
 * If needed, UMM_CRITICAL_DECL can be used to declare or initialize
 * synchronization elements before their use. "tag" can be used to add context
 * uniqueness to the declaration.
 *   exp.  #define UMM_CRITICAL_DECL(tag) uint32_t _saved_ps_##tag
 * Another possible use for "tag", activity identifier when profiling time
 * spent in UMM_CRITICAL. The "tag" values used are id_malloc, id_realloc,
 * id_free, id_poison, id_integrity, and id_info.
 *
 * NOTE WELL that these macros MUST be allowed to nest, because umm_free() is
 * called from within umm_malloc()
 */

#ifndef UMM_CRITICAL_DECL
    #define UMM_CRITICAL_DECL(tag)
#endif

#ifdef UMM_MAX_CRITICAL_DEPTH_CHECK
extern int umm_critical_depth;
extern int umm_max_critical_depth;
    #ifndef UMM_CRITICAL_ENTRY
        #define UMM_CRITICAL_ENTRY(tag) { \
            ++umm_critical_depth; \
            if (umm_critical_depth > umm_max_critical_depth) { \
                umm_max_critical_depth = umm_critical_depth; \
            } \
        }
    #endif
    #ifndef UMM_CRITICAL_EXIT
        #define UMM_CRITICAL_EXIT(tag)  (umm_critical_depth--)
    #endif
#else
   #ifndef UMM_CRITICAL_ENTRY
        #define UMM_CRITICAL_ENTRY(tag)
    #endif
    #ifndef UMM_CRITICAL_EXIT
        #define UMM_CRITICAL_EXIT(tag)
    #endif
#endif

/*
 * Enables heap integrity check before any heap operation. It affects
 * performance, but does NOT consume extra memory.
 *
 * If integrity violation is detected, the message is printed and user-provided
 * callback is called: `UMM_HEAP_CORRUPTION_CB()`
 *
 * Note that not all buffer overruns are detected: each buffer is aligned by
 * 4 bytes, so there might be some trailing "extra" bytes which are not checked
 * for corruption.
 */

#ifdef UMM_INTEGRITY_CHECK
extern bool umm_multi_integrity_check(struct umm_heap_config *heap);
extern bool umm_integrity_check(void);
#define INTEGRITY_CHECK() umm_integrity_check()
extern void umm_corruption(void);
#define UMM_HEAP_CORRUPTION_CB() printf("Heap Corruption!\n")
#else
#define INTEGRITY_CHECK() (1)
#endif

/*
 * Enables heap poisoning: add predefined value (poison) before and after each
 * allocation, and check before each heap operation that no poison is
 * corrupted.
 *
 * Other than the poison itself, we need to store exact user-requested length
 * for each buffer, so that overrun by just 1 byte will be always noticed.
 *
 * Customizations:
 *
 *    UMM_POISON_SIZE_BEFORE:
 *      Number of poison bytes before each block, e.g. 4
 *    UMM_POISON_SIZE_AFTER:
 *      Number of poison bytes after each block e.g. 4
 *    UMM_POISONED_BLOCK_LEN_TYPE
 *      Type of the exact buffer length, e.g. `uint16_t`
 *
 * NOTE: each allocated buffer is aligned by 4 bytes. But when poisoning is
 * enabled, actual pointer returned to user is shifted by
 * `(sizeof(UMM_POISONED_BLOCK_LEN_TYPE) + UMM_POISON_SIZE_BEFORE)`.
 *
 * It's your responsibility to make resulting pointers aligned appropriately.
 *
 * If poison corruption is detected, the message is printed and user-provided
 * callback is called: `UMM_HEAP_CORRUPTION_CB()`
 */

#ifdef UMM_POISON_CHECK
  #define UMM_POISON_SIZE_BEFORE (4)
  #define UMM_POISON_SIZE_AFTER (4)
  #define UMM_POISONED_BLOCK_LEN_TYPE uint16_t

extern void *umm_multi_poison_malloc(struct umm_heap_config *heap, size_t size);
extern void *umm_multi_poison_calloc(struct umm_heap_config *heap, size_t num, size_t size);
extern void *umm_multi_poison_realloc(struct umm_heap_config *heap, void *ptr, size_t size);
extern void  umm_multi_poison_free(struct umm_heap_config *heap, void *ptr);
extern bool  umm_multi_poison_check(struct umm_heap_config *heap);

extern void *umm_poison_malloc(size_t size);
extern void *umm_poison_calloc(size_t num, size_t size);
extern void *umm_poison_realloc(void *ptr, size_t size);
extern void  umm_poison_free(void *ptr);
extern bool  umm_poison_check(void);

  #define POISON_CHECK() umm_poison_check()
#else
  #define POISON_CHECK() (1)
#endif

/*
 * Add blank macros for DBGLOG_xxx() - if you want to override these on
 * a per-source module basis, you must define DBGLOG_LEVEL and then
 * #include "dbglog.h"
 */

#if DBGLOG_LEVEL == 0
#define DBGLOG_TRACE(format, ...)
#define DBGLOG_DEBUG(format, ...)
#define DBGLOG_CRITICAL(format, ...)
#define DBGLOG_ERROR(format, ...)
#define DBGLOG_WARNING(format, ...)
#define DBGLOG_INFO(format, ...)
#endif

#endif /* _UMM_MALLOC_CFG_H */
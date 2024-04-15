#ifndef __PSPIN_IOCTL_H__
#define __PSPIN_IOCTL_H__

#include <linux/ioctl.h>
#include <linux/types.h>

#ifdef __FPSPIN_HOST__
#include <stdbool.h>
#include <stdint.h>
#define u64 uint64_t
#define dma_addr_t uint64_t
#endif

struct ctx_dma_area {
  dma_addr_t dma_handle;
  u64 dma_size;
  bool enabled;
};

struct pspin_ioctl_msg {
  union {
    union {
      struct {
        int ctx_id;
      } req;
      struct ctx_dma_area resp;
    } query;
    struct {
      u64 addr;
      u64 data;
    } write;
    struct {
      u64 word; // req: addr; resp: data
    } read;
  };
};

#define PSPIN_IOCTL_MAGIC 0x95910
#define PSPIN_HOSTDMA_QUERY _IOWR(PSPIN_IOCTL_MAGIC, 0x1, struct pspin_ioctl_msg)
#define PSPIN_HOST_WRITE _IOW(PSPIN_IOCTL_MAGIC, 0x2, struct pspin_ioctl_msg)
#define PSPIN_HOST_READ _IOR(PSPIN_IOCTL_MAGIC, 0x3, struct pspin_ioctl_msg)

#endif // __PSPIN_IOCTL_H__
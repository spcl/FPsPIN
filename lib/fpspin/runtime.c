#include "fpspin.h"

#include <assert.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <unistd.h>

#define NM "nm"

void hexdump(const volatile void *data, size_t size) {
  char ascii[17];
  size_t i, j;
  ascii[16] = '\0';
  for (i = 0; i < size; ++i) {
    printf("%02X ", ((unsigned char *)data)[i]);
    if (((unsigned char *)data)[i] >= ' ' &&
        ((unsigned char *)data)[i] <= '~') {
      ascii[i % 16] = ((unsigned char *)data)[i];
    } else {
      ascii[i % 16] = '.';
    }
    if ((i + 1) % 8 == 0 || i + 1 == size) {
      printf(" ");
      if ((i + 1) % 16 == 0) {
        printf("|  %s \n", ascii);
      } else if (i + 1 == size) {
        ascii[(i + 1) % 16] = '\0';
        if ((i + 1) % 16 <= 8) {
          printf(" ");
        }
        for (j = (i + 1) % 16; j < 16; ++j) {
          printf("   ");
        }
        printf("|  %s \n", ascii);
      }
    }
  }
}

bool fpspin_init(fpspin_ctx_t *ctx, const char *dev, const char *img,
                 int dest_ctx, const fpspin_ruleset_t *rs, int num_rs,
                 int hostdma_pages) {
  if (!fpspin_get_regs_base())
    fpspin_set_regs_base("/sys/devices/pci0000:00/0000:00:03.1/0000:1d:00.0/"
                         "mqnic.app_12340100.0");

  ctx->fd = open(dev, O_RDWR | O_CLOEXEC | O_SYNC);
  if (ctx->fd < 0) {
    perror("open pspin device");
    exit(EXIT_FAILURE);
  }
  ctx->ctx_id = dest_ctx;

  if (hostdma_pages) {
    ctx->mmap_len = hostdma_pages * PAGE_SIZE;
    ctx->cpu_addr = mmap(NULL, ctx->mmap_len, PROT_READ | PROT_WRITE,
                         MAP_SHARED, ctx->fd, dest_ctx * ctx->mmap_len);
    if (ctx->cpu_addr == MAP_FAILED) {
      perror("map host dma area");
      goto fail;
    }
    if (madvise(ctx->cpu_addr, ctx->mmap_len, MADV_DONTFORK)) {
      perror("madvise DONTFORK");
      goto unmap;
    }
    printf("Mapped host dma at [%p:%p]\n", ctx->cpu_addr,
           ctx->cpu_addr + ctx->mmap_len);
  }

  struct pspin_ioctl_msg msg = {
      .query.req.ctx_id = dest_ctx,
  };
  if (ioctl(ctx->fd, PSPIN_HOSTDMA_QUERY, &msg) < 0) {
    perror("ioctl query hostdma");
    goto unmap;
  }

  assert(msg.query.resp.enabled);
  printf("Host DMA physical addr: %#lx, size: %ld\n", msg.query.resp.dma_handle,
         msg.query.resp.dma_size);

  fpspin_load(ctx, img, msg.query.resp.dma_handle, msg.query.resp.dma_size);
  fpspin_prog_me(rs, num_rs);

  // get host flag
  char cmd_buf[1024];
  snprintf(cmd_buf, sizeof(cmd_buf), NM " %s | grep __host_data", img);
  FILE *nm_fp = popen(cmd_buf, "r");
  if (!nm_fp) {
    perror("nm to get host flag");
    goto close_dev;
  }
  if (fscanf(nm_fp, "%lx", &ctx->host_data_ptr) < 1) {
    fprintf(stderr, "failed to get host flags offset\n");
    goto close_dev;
  }
  fclose(nm_fp);
  printf("Host flags at %#lx\n", ctx->host_data_ptr);

  memset(ctx->dma_idx, 0, sizeof(ctx->dma_idx));

  // initialise per-HPU DMA flag
  for (int i = 0; i < NUM_HPUS; ++i) {
    volatile uint8_t *flag_addr = (uint8_t *)ctx->cpu_addr + i * PAGE_SIZE;
    volatile uint64_t *flag = (uint64_t *)flag_addr;

    fpspin_flag_t flag_to_host = {
        .data = *flag,
    };
    ctx->dma_idx[i] = flag_to_host.dma_id;
  }

  return true;

close_dev:
  if (close(ctx->fd)) {
    perror("close pspin device");
  }

unmap:
  if (munmap(ctx->cpu_addr, ctx->mmap_len)) {
    perror("unmap");
  }

fail:
  return false;
}

void fpspin_exit(fpspin_ctx_t *ctx) {
  // shutdown ME to avoid packets writing to non-existent host memory
  fpspin_unload(ctx);

  if (close(ctx->fd)) {
    perror("close pspin device");
  }

  if (munmap(ctx->cpu_addr, ctx->mmap_len)) {
    perror("unmap");
  }
}

volatile void *fpspin_pop_req(fpspin_ctx_t *ctx, int hpu_id, fpspin_flag_t *f) {
  volatile uint8_t *flag_addr = (uint8_t *)ctx->cpu_addr + hpu_id * PAGE_SIZE;
  volatile fpspin_flag_t *flag = (fpspin_flag_t *)flag_addr;

  *f = *flag;
  if (f->dma_id == ctx->dma_idx[hpu_id])
    return NULL;

  int dest = f->hpu_id;
  if (dest != hpu_id) {
    printf("HPU ID mismatch!  Actual HPU ID: %d\n", dest);
  }

  // set as processed
  ctx->dma_idx[hpu_id] = f->dma_id;

  // returns the rest of the flag page for the core
  return flag_addr + DMA_ALIGN;
}

void fpspin_push_resp(fpspin_ctx_t *ctx, int hpu_id, fpspin_flag_t flag) {
  // make sure memory writes finish
  __sync_synchronize();

  flag.dma_id = ctx->dma_idx[hpu_id];
  flag.hpu_id = hpu_id;

  // notify pspin via host flag
  struct pspin_ioctl_msg flag_msg = {
      .write.addr = (uint64_t)&ctx->pspin_host_data->flag[hpu_id],
      .write.data = flag.data,
  };
  if (ioctl(ctx->fd, PSPIN_HOST_WRITE, &flag_msg) < 0) {
    perror("ioctl pspin device");
  }
}

void fpspin_clear_counter(fpspin_ctx_t *ctx, int id) {
  uint64_t perf_off = (uint64_t)&ctx->pspin_host_data->counters[id];
  struct pspin_ioctl_msg perf_msg = {
      .write.addr = perf_off,
      .write.data = 0UL,
  };
  if (ioctl(ctx->fd, PSPIN_HOST_WRITE, &perf_msg) < 0) {
    perror("ioctl pspin device");
  }
}

double fpspin_get_cycles(fpspin_ctx_t *ctx, int id) {
  fpspin_counter_t counter = fpspin_get_counter(ctx, id);

  return (double)counter.sum / counter.count;
}

fpspin_counter_t fpspin_get_counter(fpspin_ctx_t *ctx, int id) {
  uint64_t perf_off = (uint64_t)&ctx->pspin_host_data->counters[id];
  struct pspin_ioctl_msg perf_msg = {
      .read.word = perf_off,
  };
  if (ioctl(ctx->fd, PSPIN_HOST_READ, &perf_msg) < 0) {
    perror("ioctl pspin device");
  }
  return (fpspin_counter_t){
      .sum = (uint32_t)perf_msg.read.word,
      .count = (uint32_t)(perf_msg.read.word >> 32),
  };
}

uint32_t fpspin_get_avg_cycles(fpspin_ctx_t *ctx) {
  fpspin_counter_t counter = fpspin_get_counter(ctx, 0);
  return counter.count ? counter.sum / counter.count : 0;
}
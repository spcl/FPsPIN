#include "fpspin.h"

#include <arpa/inet.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *regs_base = NULL;

#define TOOLCHAIN "/opt/riscv/bin/riscv32-unknown-elf-"
#define OBJCOPY TOOLCHAIN "objcopy"
#define NM TOOLCHAIN "nm"
#define READELF TOOLCHAIN "readelf"
#define DEV "/dev/pspin0"

void fpspin_set_regs_base(const char *rbase) { regs_base = rbase; }
const char *fpspin_get_regs_base() { return regs_base; }

// should never fail, so we exit if failed
static void write_reg(const char *name, int id, uint32_t val) {
  const char *base = fpspin_get_regs_base();
  if (!base) {
    fprintf(stderr, "FATAL: register base not set\n");
    exit(EXIT_FAILURE);
  }
  char buf[1024];
  snprintf(buf, sizeof(buf), "%s/%s/%d", base, name, id);
  FILE *fp = fopen(buf, "w");
  if (!fp) {
    fprintf(stderr, "failed to open %s\n", buf);
    perror("open reg");
    exit(EXIT_FAILURE);
  }
  fprintf(fp, "%u", val);
  if (fclose(fp) == EOF) {
    perror("write reg");
    exit(EXIT_FAILURE);
  }
}

static void cycle_reset() {
  write_reg("cl/ctrl", 1, 1);
  write_reg("cl/ctrl", 1, 0);
}

static void fetch_on() { write_reg("cl/ctrl", 0, (1 << NUM_CLUSTERS) - 1); }
static void fetch_off() { write_reg("cl/ctrl", 0, 0); }

static void me_on() { write_reg("me/valid", 0, 1); }
static void me_off() { write_reg("me/valid", 0, 0); }

static void her_on() { write_reg("her/valid", 0, 1); }
static void her_off() { write_reg("her/valid", 0, 0); }

static void set_me_rule(int ctx_id, int rid, const struct fpspin_rule *ru) {
  int reg_id = ctx_id * NUM_RULES_PER_RULESET + rid;
  // FIXME: do we need idx to be big endian as well?
  write_reg("me/idx", reg_id, ru->idx);
  write_reg("me/mask", reg_id, htonl(ru->mask));
  write_reg("me/start", reg_id, htonl(ru->start));
  write_reg("me/end", reg_id, htonl(ru->end));
}

static void dump_me_rule(const struct fpspin_rule *ru) {
  printf("... %d:\t%08x [%08x:%08x]\n", ru->idx, ru->mask, ru->start, ru->end);
}

static void dump_me_ruleset(const fpspin_ruleset_t *rs) {
  printf("Ruleset %s:\n", rs->mode == FPSPIN_MODE_AND ? "MODE_AND" : "MODE_OR");
  for (int i = 0; i < NUM_RULES_PER_RULESET; ++i) {
    dump_me_rule(&rs->r[i]);
  }
}

void fpspin_set_me_ruleset(int ctx_id, const fpspin_ruleset_t *rs) {
  for (int i = 0; i < NUM_RULES_PER_RULESET; ++i) {
    set_me_rule(ctx_id, i, &rs->r[i]);
  }
}

void fpspin_ruleset_bypass(fpspin_ruleset_t *rs) {
  rs->mode = FPSPIN_MODE_AND;
  for (int i = 0; i < NUM_RULES_PER_RULESET; ++i) {
    rs->r[i] = FPSPIN_RULE_FALSE;
  }
}
void fpspin_ruleset_match(fpspin_ruleset_t *rs) {
  rs->mode = FPSPIN_MODE_AND;
  for (int i = 0; i < NUM_RULES_PER_RULESET; ++i) {
    rs->r[i] = FPSPIN_RULE_EMPTY;
  }
}

void fpspin_ruleset_udp(fpspin_ruleset_t *rs) {
  assert(NUM_RULES_PER_RULESET == 4);
  *rs = (fpspin_ruleset_t){
      .mode = FPSPIN_MODE_AND,
      .r =
          {
              FPSPIN_RULE_IP,
              FPSPIN_RULE_IP_PROTO(17),
              FPSPIN_RULE_EMPTY,
              FPSPIN_RULE_FALSE,
          },
  };
}

void fpspin_ruleset_slmp(fpspin_ruleset_t *rs) {
  assert(NUM_RULES_PER_RULESET == 4);
  *rs = (fpspin_ruleset_t){
      .mode = FPSPIN_MODE_AND,
      .r =
          {
              FPSPIN_RULE_IP, FPSPIN_RULE_IP_PROTO(17),
              FPSPIN_RULE_UDP_DPORT(9330),
              ((struct fpspin_rule){
                  .idx = 10,
                  .mask = 0x8000,
                  .start = 0x8000,
                  .end = 0x8000}), // first bit (EOM) in flags in SLMP
          },
  };
  // message ID rule in hardware
}

void fpspin_write_memory(fpspin_ctx_t *ctx, fpspin_addr_t pspin_addr,
                         void *host_addr, size_t len) {
  uint64_t off = pspin_addr;

  int dev_fd = ctx->fd;
  if (dev_fd < 0) {
    perror("open pspin device");
    exit(EXIT_FAILURE);
  }
  if (lseek(dev_fd, off, SEEK_SET) < 0) {
    perror("seek device");
    exit(EXIT_FAILURE);
  }
  size_t bytes_written;
  do {
    bytes_written = write(dev_fd, host_addr, len);
    if (bytes_written < 0) {
      perror("write to device");
      exit(EXIT_FAILURE);
    }
    len -= bytes_written;
    host_addr += bytes_written;
  } while (len);
}

static void write_section(fpspin_ctx_t *ctx, const char *elf,
                          const char *section, uint64_t addr) {
  char buf[1024];
  const char *tmp = tmpnam(NULL);
  snprintf(buf, sizeof(buf), OBJCOPY " -O binary --only-section=%s %s %s",
           section, elf, tmp);
  // FIXME: check return value
  if (system(buf) < 0) {
    perror("system");
    exit(EXIT_FAILURE);
  }
  int sec_fd = open(tmp, O_RDONLY);
  if (sec_fd < 0) {
    perror("open objcopy result");
    exit(EXIT_FAILURE);
  }
  char bin_buf[4096];
  int bytes_read;
  do {
    bytes_read = read(sec_fd, bin_buf, sizeof(bin_buf));
    if (bytes_read < 0) {
      perror("read objcopy result");
      exit(EXIT_FAILURE);
    }
    fpspin_write_memory(ctx, addr, bin_buf, bytes_read);
    addr += bytes_read;
  } while (bytes_read > 0);
  close(sec_fd);
  unlink(tmp);
}

static void set_handler(const char *elf, const char *handler, int ctx_id,
                        struct mem_area *out_area) {
  uint32_t haddr, hsize;
  char buf[1024];
  snprintf(buf, sizeof(buf), NM " %s | grep _%s", elf, handler);
  FILE *fp = popen(buf, "r");
  if (!fp) {
    perror("call nm");
    exit(EXIT_FAILURE);
  }
  if (fscanf(fp, "%x", &haddr) == EOF && !errno) {
    if (!errno) {
      haddr = 0;
      hsize = 0;
    } else {
      perror("fscanf nm");
      exit(EXIT_FAILURE);
    }
  } else {
    hsize = 4096;
  }
  pclose(fp);

  char regname[32];

  printf("%s: %#x (size %d)\n", handler, haddr, hsize);

  out_area->addr = haddr;
  out_area->size = hsize;

  snprintf(regname, sizeof(regname), "her_meta/%s_addr", handler);
  write_reg(regname, ctx_id, haddr);

  snprintf(regname, sizeof(regname), "her_meta/%s_size", handler);
  write_reg(regname, ctx_id, hsize);
}

static void set_handler_mem(const char *elf, int ctx_id,
                            struct mem_area *out_area) {
  uint32_t l2_daddr, l2_dsize;
  char buf[1024];
  snprintf(buf, sizeof(buf), READELF " -S %s | grep l2_handler_data", elf);
  FILE *fp = popen(buf, "r");
  if (!fp) {
    perror("call readelf");
    exit(EXIT_FAILURE);
  }
  assert(fscanf(fp, "%*s %*s %*s %x %*x %x", &l2_daddr, &l2_dsize) == 2);
  pclose(fp);

  uint32_t mem_addr = l2_daddr + l2_dsize;
  uint32_t mem_size = L2_END - l2_daddr;

  printf("Handler memory addr: %#x, size: %d\n", mem_addr, mem_size);

  out_area->addr = mem_addr;
  out_area->size = mem_size;

  write_reg("her_meta/handler_mem_addr", ctx_id, mem_addr);
  write_reg("her_meta/handler_mem_size", ctx_id, mem_size);
}

void fpspin_prog_me(const fpspin_ruleset_t *rs, int num_rs) {
  if (num_rs > NUM_RULESETS) {
    fprintf(stderr, "Too many rulesets configured: device has %d\n",
            NUM_RULESETS);
    exit(EXIT_FAILURE);
  }

  me_off();
  fpspin_ruleset_t bypass;
  fpspin_ruleset_bypass(&bypass);
  for (int i = 0; i < NUM_RULESETS; ++i) {
    if (i >= num_rs) {
      fpspin_set_me_ruleset(i, &bypass);
    } else {
      fpspin_set_me_ruleset(i, rs + i);
      dump_me_ruleset(rs + i);
    }
  }
  me_on();
}

void fpspin_load(fpspin_ctx_t *ctx, const char *elf, uint64_t hostmem_ptr,
                 uint32_t hostmem_size) {
  fetch_off();
  cycle_reset();

  int ctx_id = ctx->ctx_id;

  // FIXME: relocation such that multiple contexts can really co-exist
  // readelf -S ; sw/pulp-sdk/linker/link.ld
  write_section(ctx, elf, ".rodata", 0x1c000000);
  write_section(ctx, elf, ".l2_handler_data", 0x1c0c0000);
  write_section(ctx, elf, ".vectors", 0x1d000000);
  write_section(ctx, elf, ".text", 0x1d000100);
  fetch_on();

  her_off();
  set_handler(elf, "hh", ctx_id, &ctx->hh);
  set_handler(elf, "ph", ctx_id, &ctx->ph);
  set_handler(elf, "th", ctx_id, &ctx->th);
  set_handler_mem(elf, ctx_id, &ctx->handler_mem);

  write_reg("her_meta/host_mem_addr_1", ctx_id, hostmem_ptr >> 32);
  write_reg("her_meta/host_mem_addr_0", ctx_id, hostmem_ptr);
  write_reg("her_meta/host_mem_size", ctx_id, hostmem_size);

  // scratchpad 0 and 1 - address is calculated in hardware
  write_reg("her_meta/scratchpad_0_size", ctx_id, 4096);
  write_reg("her_meta/scratchpad_1_size", ctx_id, 4096);

  write_reg("her/ctx_enabled", ctx_id, 1);
  her_on();
}

void fpspin_unload(fpspin_ctx_t *ctx) {
  int ctx_id = ctx->ctx_id;

  printf("Unloading cluster...\n");
  // disable fetch
  fetch_off();
  // reset
  cycle_reset();
  // bypass rule
  me_off();
  fpspin_ruleset_t bypass;
  fpspin_ruleset_bypass(&bypass);
  fpspin_set_me_ruleset(ctx_id, &bypass);
  me_on();
}
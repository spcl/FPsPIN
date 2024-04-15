#ifndef __FPSPIN_H__
#define __FPSPIN_H__

#include "../../fpga/app/pspin/modules/mqnic_app_pspin/pspin_ioctl.h"

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <arpa/inet.h>

typedef struct mac_addr {
  uint8_t data[6];
} __attribute__((__packed__)) mac_addr_t;

typedef struct eth_hdr {
  mac_addr_t dest;
  mac_addr_t src;
  uint16_t length;
} __attribute__((__packed__)) eth_hdr_t;

typedef struct ip_hdr {
  // ip-like
  // FIXME: bitfield endianness is purely compiler-dependent
  // we should use bit operations
  uint8_t ihl : 4;
  uint8_t version : 4;
  uint8_t tos;
  uint16_t length;

  uint16_t identification;
  uint16_t offset;

  uint8_t ttl;
  uint8_t protocol;
  uint16_t checksum;

  uint32_t source_id; // 4
  uint32_t dest_id;   // 4

} __attribute__((__packed__)) ip_hdr_t;

typedef struct udp_hdr {
  uint16_t src_port;
  uint16_t dst_port;
  uint16_t length;
  uint16_t checksum;
} __attribute__((__packed__)) udp_hdr_t;

// sPIN Lightweight Message Protocol
typedef struct slmp_hdr {
  uint16_t flags;
  uint32_t msg_id;  // larger than needed, but for alignment purposes (Ethernet
                    // header is 6 bytes)
  uint32_t pkt_off; // packet offset in message
} __attribute__((__packed__)) slmp_hdr_t;

typedef struct slmp_pkt_hdr {
  eth_hdr_t eth_hdr;
  ip_hdr_t ip_hdr; // FIXME: assumes ihl=4
  udp_hdr_t udp_hdr;
  slmp_hdr_t slmp_hdr;
} __attribute__((__packed__)) slmp_pkt_hdr_t;
#define MKEOM 0x8000
#define MKSYN 0x4000
#define MKACK 0x2000
#define EOM(flags) ((flags)&MKEOM)
#define SYN(flags) ((flags)&MKSYN)
#define ACK(flags) ((flags)&MKACK)

#define SLMP_PAYLOAD_SIZE 1462
#define SLMP_PORT 9330

typedef struct {
  bool parallel;
  int wnd_sz;
  int align;
  int fc_us;
  int num_threads;
} slmp_sock_t;
int slmp_socket(slmp_sock_t *sock, int wnd_sz, int align, int fc_us,
                int num_threads);
int slmp_sendmsg(slmp_sock_t *sock, in_addr_t server, int msgid, void *buf,
                 size_t sz);
int slmp_close(slmp_sock_t *sock);

/*
typedef struct app_hdr
{ //QUIC-like
    uint64_t            connection_id;
    uint16_t            packet_num;
    uint16_t             frame_type; //frame_type 1: connection closing
} __attribute__((__packed__)) app_hdr_t;
*/
typedef struct pkt_hdr {
  eth_hdr_t eth_hdr;
  ip_hdr_t ip_hdr;
  udp_hdr_t udp_hdr;
  // app_hdr_t app_hdr;
} __attribute__((__packed__)) pkt_hdr_t;

#define NUM_HPUS 16

typedef uint32_t fpspin_addr_t;
struct mem_area {
  fpspin_addr_t addr;
  uint32_t size;
};

// XXX: keep in sync with pspin.h
#define MAX_COUNTERS 16
typedef struct perf_counter {
  uint32_t sum;
  uint32_t count;
} fpspin_counter_t;

struct host_data {
  uint64_t flag[NUM_HPUS];
  struct perf_counter counters[MAX_COUNTERS];
};

typedef struct {
  int ctx_id;
  int fd;
  void *cpu_addr;
  size_t mmap_len;
  uint8_t dma_idx[NUM_HPUS];
  union {
    struct host_data *pspin_host_data;
    uint64_t host_data_ptr;
  };

  // image information
  struct mem_area hh, ph, th;
  struct mem_area handler_mem;

  // user pointer
  void *app_data;
} fpspin_ctx_t;

// TODO: do proper descriptor ring
typedef struct {
  union {
    struct {
      uint8_t dma_id;
      uint32_t len;
      uint16_t hpu_id;
    } __attribute__((packed));
    uint64_t data;
  };
} fpspin_flag_t;
static_assert(sizeof(fpspin_flag_t) == sizeof(uint64_t),
              "flag size not correct");

#define DMA_BUS_WIDTH 512
#define DMA_ALIGN (DMA_BUS_WIDTH / 8)

#define L2_END 0x1c100000UL
#define PAGE_SIZE 4096

void hexdump(const volatile void *data, size_t size);

// public API
// XXX: rbase should have static lifetime
void fpspin_set_regs_base(const char *rbase);
const char *fpspin_get_regs_base();

#define NUM_RULES_PER_RULESET 4
#define NUM_RULESETS 4

// hw/verilator_model/include/spin_hw_conf.h
#ifndef __VERILATOR__
#define NUM_CLUSTERS 2
#endif

typedef struct {
  struct fpspin_rule {
    int idx;
    uint32_t mask;
    uint32_t start;
    uint32_t end;
  } r[NUM_RULES_PER_RULESET];
  enum {
    FPSPIN_MODE_AND,
    FPSPIN_MODE_OR,
  } mode;
} fpspin_ruleset_t;

#define FPSPIN_RULE_FALSE ((struct fpspin_rule){0, 0, 1, 0})
#define FPSPIN_RULE_EMPTY ((struct fpspin_rule){0, 0, 0, 0})
#define FPSPIN_RULE_IP                                                         \
  ((struct fpspin_rule){                                                       \
      .idx = 3, .mask = 0xffff0000, .start = 0x08000000, .end = 0x08000000})
#define FPSPIN_RULE_IP_PROTO(num)                                              \
  ((struct fpspin_rule){.idx = 5, .mask = 0xff, .start = num, .end = num})
#define FPSPIN_RULE_UDP_SPORT(num)                                             \
  ((struct fpspin_rule){                                                       \
      .idx = 8, .mask = 0xffff, .start = htons(num), .end = htons(num)})
#define FPSPIN_RULE_UDP_DPORT(num)                                             \
  ((struct fpspin_rule){                                                       \
      .idx = 9, .mask = 0xffff0000, .start = num << 16, .end = num << 16})

void fpspin_set_me_ruleset(int ctx_id, const fpspin_ruleset_t *rs);
void fpspin_ruleset_bypass(fpspin_ruleset_t *rs);
void fpspin_ruleset_match(fpspin_ruleset_t *rs);
void fpspin_ruleset_udp(fpspin_ruleset_t *rs);
void fpspin_ruleset_slmp(fpspin_ruleset_t *rs);

void fpspin_prog_me(const fpspin_ruleset_t *rs, int num_rs);
void fpspin_load(fpspin_ctx_t *ctx, const char *elf, uint64_t hostmem_ptr,
                 uint32_t hostmem_size);
void fpspin_unload(fpspin_ctx_t *ctx);

#define FPSPIN_HOSTDMA_PAGES_DEFAULT 16
bool fpspin_init(fpspin_ctx_t *ctx, const char *dev, const char *img,
                 int dest_ctx, const fpspin_ruleset_t *rs, int num_rs,
                 int hostdma_pages);
void fpspin_exit(fpspin_ctx_t *ctx);
// TODO: rework to use streaming DMA; the coherent buffer should only be used
// for descriptors
// XXX: multi-core and out-of-order response (with ring buffer)?
volatile void *fpspin_pop_req(fpspin_ctx_t *ctx, int hpu_id, fpspin_flag_t *f);
void fpspin_push_resp(fpspin_ctx_t *ctx, int hpu_id, fpspin_flag_t flag);

static_assert(sizeof(fpspin_counter_t) == sizeof(uint64_t),
              "counter size should not exceed a uint64_t");
double fpspin_get_cycles(fpspin_ctx_t *ctx, int id);
fpspin_counter_t fpspin_get_counter(fpspin_ctx_t *ctx, int id);
void fpspin_clear_counter(fpspin_ctx_t *ctx, int id);
uint32_t fpspin_get_avg_cycles(fpspin_ctx_t *ctx);

// for initialising handler memory from host dynamically
void fpspin_write_memory(fpspin_ctx_t *ctx, fpspin_addr_t pspin_addr,
                         void *host_addr, size_t len);

#endif // __FPSPIN_H__
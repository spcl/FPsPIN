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

#include "pspin.h"
#include <handler.h>
#include <packets.h>
#include <spin_dma.h>
#include <spin_host.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(FROM_L2) && !defined(FROM_L1)
#define FROM_L1
#endif

// #define DEBUG(...) printf(__VA_ARGS__)
#define DEBUG(...)

// FIXME: only for ICMP echo
typedef struct {
  uint8_t type;
  uint8_t code;
  uint16_t checksum;
  uint32_t rest_of_header;
} icmp_hdr_t;

typedef struct {
  eth_hdr_t eth_hdr;
  ip_hdr_t ip_hdr; // FIXME: assumes ihl=4
  icmp_hdr_t icmp_hdr;
} __attribute__((__packed__)) hdr_t;


uint16_t ip_checksum_timo(void *vdata, size_t length) {
  // Cast the data pointer to one that can be indexed.
  uint16_t *data = vdata;
  uint8_t *data8 = vdata;

  // Initialise the accumulator.
  uint32_t acc = 0xffff;

  // Handle complete 16-bit blocks.
  for (size_t i = 0; i < (length >> 1); i++) { acc += data[i]; }
  // Handle any partial block at the end of the data.
  if (length & 1) { acc += data8[length-1]; }
  // fold acc (upper 16 bits are the accumulated carry bits)
  acc = (acc & 0xffff) + ((acc >> 16) & 0xffff); //fold acc (could cause a carry)
  acc = (acc & 0xffff) + ((acc >> 16) & 0xffff); //fold acc again (take care of carry)

  return ~acc;

}


__handler__ void pingpong_ph(handler_args_t *args) {
  DEBUG("Packet @ %p (L2: %p) (size %d) flow_id %d\n", args->task->pkt_mem,
        args->task->l2_pkt_mem, args->task->pkt_mem_size, args->task->flow_id);

  task_t *task = args->task;

  hdr_t *hdrs = (hdr_t *)(task->pkt_mem);
  uint16_t pkt_len = args->task->pkt_mem_size;
#ifdef FROM_L2
  uint8_t *nic_pld_addr = ((uint8_t *)(task->l2_pkt_mem));
#else
  uint8_t *nic_pld_addr = ((uint8_t *)(task->pkt_mem));
#endif

  // ICMP ping: swap MAC and IP address
  mac_addr_t src_mac = hdrs->eth_hdr.src;
  hdrs->eth_hdr.src = hdrs->eth_hdr.dest;
  hdrs->eth_hdr.dest = src_mac;

  uint32_t src_id = hdrs->ip_hdr.source_id;
  hdrs->ip_hdr.source_id = hdrs->ip_hdr.dest_id;
  hdrs->ip_hdr.dest_id = src_id;

  spin_cmd_t dma;
  fpspin_flag_t flag_from_host;

  if (DO_HOST && fpspin_check_host_mem(args)) {
    // DMA packet data
    spin_dma_to_host(HOST_PLD_ADDR(args), (uint32_t)nic_pld_addr, pkt_len, 1,
                     &dma);
    spin_cmd_wait(dma);
    DEBUG("Written packet data\n");

    flag_from_host = fpspin_host_req(args, pkt_len);
    uint16_t host_pkt_len = flag_from_host.len;

    // DMA packet data back
    spin_dma_from_host(HOST_PLD_ADDR(args), (uint32_t)nic_pld_addr,
                       host_pkt_len, 1, &dma);
    spin_cmd_wait(dma);


    DEBUG("DMA roundtrip finished, packet from host size: %d\n", host_pkt_len);
    pkt_len = host_pkt_len;
  } else {
    // calculate ICMP checksum ourselves
    uint16_t ip_len = ntohs(hdrs->ip_hdr.length);
    uint16_t icmp_len = ip_len - sizeof(ip_hdr_t);
    hdrs->icmp_hdr.type = 0; // Echo-Reply
    hdrs->icmp_hdr.checksum = 0;
    hdrs->icmp_hdr.checksum = ip_checksum_timo((uint8_t *)&hdrs->icmp_hdr, icmp_len);
    pkt_len = ip_len + sizeof(eth_hdr_t);
  }

  spin_cmd_t put;
  spin_send_packet(nic_pld_addr, pkt_len, &put);
  spin_cmd_wait(put);

}

void init_handlers(handler_fn *hh, handler_fn *ph, handler_fn *th,
                   void **handler_mem_ptr) {
  volatile handler_fn handlers[] = {NULL, pingpong_ph, NULL};
  *hh = handlers[0];
  *ph = handlers[1];
  *th = handlers[2];
}

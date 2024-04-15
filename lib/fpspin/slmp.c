#include "fpspin.h"

#include <asm-generic/errno.h>
#include <asm-generic/socket.h>
#include <errno.h>
#include <omp.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#if 0
#define DEBUG(fmt, ...)                                                        \
  printf("%s[%d]: " fmt, __func__, omp_get_thread_num(), __VA_ARGS__)
#else
#define DEBUG(...)
#endif

int slmp_socket(slmp_sock_t *sock, int wnd_sz, int align, int fc_us,
                int num_threads) {
  if (num_threads <= 0) {
    fprintf(stderr, "number of threads <= 0\n");
    goto fail;
  }
  if (wnd_sz < 0) {
    fprintf(stderr, "window size < 0\n");
    goto fail;
  }
  // window size == 0: unlimited window / no ACK
  sock->wnd_sz = wnd_sz; // negative: no ACK
  sock->align = align;
  sock->fc_us = fc_us;
  sock->num_threads = num_threads;
  return 0;

fail:
  errno = EINVAL;
  return -1;
}

static int drain_ack(int sockfd, int to_expect) {
  int acked = 0;
  for (int i = 0; i < to_expect; ++i) {
    slmp_hdr_t ack;
    ssize_t rcvd = recvfrom(sockfd, &ack, sizeof(ack), 0, NULL, NULL);
    // we should be bound at this time == not setting addr
    if (rcvd < 0) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        break;
      } else {
        perror("recvfrom ACK");
        return -1;
      }
    } else if (rcvd != sizeof(slmp_hdr_t)) {
      fprintf(stderr, "ACK size mismatch: expected %ld, got %ld\n",
              sizeof(slmp_hdr_t), rcvd);
      return -1;
    }
    // check ACK
    uint16_t flags = ntohs(ack.flags);
    if (!ACK(flags)) {
      fprintf(stderr, "no ACK set in reply; flag=%#x\n", flags);
      return -1;
    }

    DEBUG("ACK seq=%d off=%d\n", ntohl(ack.msg_id), ntohl(ack.pkt_off));
    ++acked;
  }

  return acked;
}

static int drain_ack_timeout(int sockfd, int to_expect, bool need_all,
                             struct timeval *timeout) {
  DEBUG("to_expect=%d\n", to_expect);
  if (!to_expect)
    return 0;

  struct timeval start_synack, deadline_synack;
  gettimeofday(&start_synack, NULL);
  timeradd(&start_synack, timeout, &deadline_synack);

  int acked = 0;

  while (acked < to_expect) {
    int v = drain_ack(sockfd, 1);
    if (v < 0)
      return v;
    else {
      if (!v && acked &&
          !need_all) // we received at least one ack before this round, break
        break;
      if (v)
        DEBUG("received %d ACKs\n", v);
      acked += v;
    }
    if (!v) {
      // sleep for 100us so we don't completely occupy the CPU
      usleep(100);
    }

    struct timeval now;
    gettimeofday(&now, NULL);
    if (timercmp(&now, &deadline_synack, >)) {
      break;
    }
  }

  return acked;
}

static int send_single(int sockfd, int fc_us, uint8_t *cur, uint8_t *char_buf,
                       size_t sz, size_t payload_size, in_addr_t srv_addr,
                       uint16_t hflags, int msgid, bool expect_ack,
                       int *window_left, int total_window,
                       struct timeval *timeout) {
  uint8_t packet[SLMP_PAYLOAD_SIZE + sizeof(slmp_hdr_t)];
  slmp_hdr_t *hdr = (slmp_hdr_t *)packet;
  uint32_t offset = cur - char_buf;
  uint8_t *payload = packet + sizeof(slmp_hdr_t);

  DEBUG("off=%d *window_left=%d total_window=%d\n", offset, *window_left,
        total_window);

  // reclaim window if we are out
  while (expect_ack && !*window_left) {
    int v = drain_ack_timeout(sockfd, total_window, false, timeout);
    if (!v) {
      fprintf(stderr, "timeout waiting for window\n");
      return -1;
    }
    *window_left += v;
    DEBUG("reclaimed window %d, left %d\n", v, *window_left);
  }

  hdr->msg_id = htonl(msgid);
  hdr->flags = htons(hflags);
  hdr->pkt_off = htonl(offset);

  struct sockaddr_in server = {
      .sin_family = AF_INET,
      .sin_addr.s_addr = srv_addr,
      .sin_port = htons(SLMP_PORT),
  };

  size_t left = sz - (cur - char_buf);
  size_t to_copy = left > payload_size ? payload_size : left;

  memcpy(payload, cur, to_copy);

  // send the packet
  struct timeval start_sendto, deadline_sendto;
  gettimeofday(&start_sendto, NULL);
  timeradd(&start_sendto, timeout, &deadline_sendto);
  while (true) {
    int r = sendto(sockfd, packet, to_copy + sizeof(slmp_hdr_t), 0,
                   (const struct sockaddr *)&server, sizeof(server));
    if (r < 0) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        struct timeval now;
        gettimeofday(&now, NULL);
        if (timercmp(&now, &deadline_sendto, >)) {
          fprintf(stderr, "timeout sendto\n");
          return -1;
        }
        continue;
      }
      perror("sendto");
      return -1;
    } else {
      break;
    }
  }

  // update window
  --*window_left;

  // printf("Sent packet offset=%d in msg #%d\n", offset, msgid);
  if (fc_us)
    usleep(fc_us);

  return 0;
}

int slmp_sendmsg(slmp_sock_t *sock, in_addr_t srv_addr, int msgid, void *buf,
                 size_t sz) {
  // non-blocking
  int sockfd = socket(AF_INET, SOCK_DGRAM | SOCK_NONBLOCK, 0);

  // increase send and receive buffer
  int buf_sz = 1024 * 1024; // 1MB
  int ret = setsockopt(sockfd, SOL_SOCKET, SO_SNDBUF, &buf_sz, sizeof(buf_sz));
  if (ret < 0) {
    perror("setsockopt SO_SNDBUF");
    ret = -1;
    return ret;
  }
  ret = setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, &buf_sz, sizeof(buf_sz));
  if (ret < 0) {
    perror("setsockopt SO_RCVBUF");
    return ret;
  }

  struct timeval timeout = {
      .tv_sec = 1,
      .tv_usec = 0,
  };

  // window size; 0: unlimited window (no ACK)
  bool ack_for_all = sock->wnd_sz > 0;

  printf("Sending SLMP message #%d of size %ld\n", msgid, sz);
  if (sock->fc_us) {
    printf("Flow control: %d us inter-packet gap\n", sock->fc_us);
  }

  size_t payload_size = (SLMP_PAYLOAD_SIZE / sock->align) * sock->align;

  uint8_t *char_buf = (uint8_t *)buf;
  volatile bool exit_flag = false;

  uint8_t *cur = char_buf;
  uint16_t hflags = MKSYN;
  if (payload_size >= sz) {
    // will only send one message
    hflags |= MKEOM;
  }

  int syn_window = 1;
  ret = send_single(sockfd, sock->fc_us, cur, char_buf, sz, payload_size,
                    srv_addr, hflags, msgid, true, &syn_window, 1, &timeout);
  if (ret < 0) {
    fprintf(stderr, "failed to send SYN\n");
    return -3;
  }

  if (!drain_ack_timeout(sockfd, 1, true, &timeout)) {
    fprintf(stderr, "SYN timed out\n");
    return -2;
  }

  // round up
  int window_thread_limit =
      (sock->wnd_sz + sock->num_threads - 1) / sock->num_threads;
  int window_total = window_thread_limit * sock->num_threads;
  int window_thread[sock->num_threads];
  for (int i = 0; i < sock->num_threads; ++i) {
    window_thread[i] = window_thread_limit;
  }

#pragma omp parallel for \
  num_threads(sock->num_threads) \
  reduction(+ : ret) \
  shared(exit_flag, window_thread) \
  lastprivate(cur)
  for (/* first packet outside of the parallel loop*/
       cur = char_buf + payload_size;
       /* do not send last packet in the parallel loop */
       cur < char_buf + sz - payload_size; cur += payload_size) {
    if (exit_flag)
      continue;

    int *my_window = &window_thread[omp_get_thread_num()];

    bool expect_ack = true;
    uint16_t hflags;
    if (cur == char_buf) {
      // first packet requires synchronisation
      hflags = MKSYN;
    } else {
      hflags = 0;
      expect_ack = false;
    }

    if (ack_for_all) {
      hflags |= MKSYN;
      expect_ack = true;
    }

    ret = send_single(sockfd, sock->fc_us, cur, char_buf, sz, payload_size,
                      srv_addr, hflags, msgid, expect_ack, my_window,
                      window_thread_limit, &timeout);
    if (ret) {
      exit_flag = true;
      continue;
    }
  }

  if (ret) {
    ret = -1;
    goto out;
  }

  // collect all windows before sending the final segment
  int window_left = 0;
  for (int i = 0; i < sock->num_threads; ++i) {
    DEBUG("thread %d window %d limit %d\n", i, window_thread[i],
          window_thread_limit);
    window_left += window_thread[i];
  }

  DEBUG("Before last packet: left=%d total=%d\n", window_left, window_total);

  // send last packet
  if (cur < char_buf + sz)
    ret = send_single(sockfd, sock->fc_us, cur, char_buf, sz, payload_size,
                      srv_addr, MKEOM | MKSYN, msgid, true, &window_left,
                      window_total, &timeout);

  // drain all windows
  struct timeval final_timeout = {
      .tv_sec = 2, // 2 seconds
      .tv_usec = 0,
  };

  int to_drain = window_total - window_left;
  int drained = drain_ack_timeout(sockfd, to_drain, true, &final_timeout);
  DEBUG("drained %d, to_drain %d\n", drained, to_drain);
  if (drained < to_drain) {
    fprintf(stderr, "timeout waiting for final drain\n");
    ret = -1;
  }

out:
  close(sockfd);
  return ret;
}

int slmp_close(slmp_sock_t *sock) { return 0; }
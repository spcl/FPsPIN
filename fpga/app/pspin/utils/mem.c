#include <argp.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>

#include "fpspin/fpspin.h"

struct arguments {
  uint64_t addr;
  bool do_write;
  uint64_t data;
  const char *dev_file;
};

static char doc[] =
    "Read or write memory from the FPsPIN device over ioctl.  This utility "
    "calls into libfpspin to perform the read or write oepration.";
static char args_doc[] = "ADDR_HEX";

static struct argp_option options[] = {
    {"device", 'd', "DEV_FILE", 0, "pspin device file"},
    {"write", 'w', "HEX", 0, "data to write to the specified address"},
    {0}};

static error_t parse_opt(int key, char *arg, struct argp_state *state) {
  struct arguments *args = state->input;

  switch (key) {
  case 'd':
    args->dev_file = arg;
    break;
  case 'w':
    args->do_write = true;
    sscanf(arg, "%lx", &args->data);
    break;
  case ARGP_NO_ARGS:
    argp_usage(state);
    break;
  case ARGP_KEY_ARG:
    if (state->arg_num >= 1)
      argp_usage(state);
    sscanf(arg, "%lx", &args->addr);
    break;
  case ARGP_KEY_END:
    if (state->arg_num < 1)
      argp_usage(state);
    break;
  }
  return 0;
}

int main(int argc, char *argv[]) {
  static struct argp argp = {options, parse_opt, args_doc, doc};
  argp_program_version = "read_mem 1.0";
  argp_program_bug_address = "Pengcheng Xu <pengxu@ethz.ch>";
  struct arguments args = {
      .dev_file = "/dev/pspin0",
  };

  if (argp_parse(&argp, argc, argv, 0, 0, &args)) {
    return EXIT_FAILURE;
  }
  if (!args.addr) {
    fprintf(stderr, "error: no address specified (see --help)\n");
    return EXIT_FAILURE;
  }

  // FIXME: merge into libfpspin?
  int fd = open(args.dev_file, O_RDWR | O_CLOEXEC | O_SYNC);
  if (fd < 0) {
    perror("open pspin device");
    return EXIT_FAILURE;
  }

  if (args.do_write) {
    struct pspin_ioctl_msg write_msg = {
        .write.addr = args.addr,
        .write.data = args.data,
    };
    if (ioctl(fd, PSPIN_HOST_WRITE, &write_msg) < 0) {
      perror("ioctl pspin device");
      return EXIT_FAILURE;
    }
    printf("Written %#lx to %#lx\n", args.data, args.addr);
  } else {
    struct pspin_ioctl_msg read_msg = {
        .read.word = args.addr,
    };
    if (ioctl(fd, PSPIN_HOST_READ, &read_msg) < 0) {
      perror("ioctl pspin device");
      return EXIT_FAILURE;
    }
    printf("%#lx: %016lx\n", args.addr, read_msg.read.word);
  }
  return EXIT_SUCCESS;
}
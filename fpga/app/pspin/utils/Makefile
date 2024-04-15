CC = gcc
CFLAGS ?= -O3 -g -fsanitize=address -march=native -Wall -D__FPSPIN_HOST__
LIBS ?= $(shell realpath ../../../../lib)

CPPFLAGS += -I$(LIBS)
LDFLAGS += -L$(LIBS)/fpspin
LDLIBS += -lfpspin

LIBFPSPIN = $(LIBS)/fpspin/libfpspin.a

all: mem

GENDEPFLAGS = -MD -MP -MF .$(@F).d

ALL_CFLAGS = $(CFLAGS) $(CPPFLAGS) $(GENDEPFLAGS)

FORCE:

$(LIBFPSPIN): FORCE
	$(MAKE) -C $(dir $@) $(notdir $@)

%.o: %.c
	$(CC) $(ALL_CFLAGS) -c -o $@ $<

mem: mem.o $(LIBFPSPIN)
	$(CC) $(ALL_CFLAGS) $(LDFLAGS) $^ $(LDFLAGS) -o $@

clean:
	rm -f mem
	rm -f *.o
	rm -f .*.d

-include $(wildcard .*.d)

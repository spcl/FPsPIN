SPIN_APP_NAME = slmp
SPIN_APP_SRCS = handlers/slmp.c
SPIN_CFLAGS = -O3 -g -flto
SPIN_LDFLAGS = -lm

include $(PSPIN_RT)/rules/spin-handlers.mk
include ../generic_driver/gdriver.mk

host:
	$(MAKE) -C host/
sender:
	$(MAKE) -C sender/
.PHONY: host sender all

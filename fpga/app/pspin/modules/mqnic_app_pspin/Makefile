ifneq ($(KERNELRELEASE),)

KBUILD_EXTRA_SYMBOLS=$(src)/../mqnic/Module.symvers

ccflags-y += -I$(src)/../mqnic/

# object files to build
obj-m += mqnic_app_pspin.o
mqnic_app_pspin-y += main.o

else

ifneq ($(KERNEL_SRC),)
# alternatively to variable KDIR accept variable KERNEL_SRC as used in
# PetaLinux/Yocto for example
KDIR ?= $(KERNEL_SRC)
endif

KDIR ?= /lib/modules/$(shell uname -r)/build

all: modules

help modules modules_install clean:
	$(MAKE) -C $(KDIR) M=$(shell pwd) $@

install: modules_install

endif

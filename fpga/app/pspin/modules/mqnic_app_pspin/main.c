// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2022, The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation
 * are those of the authors and should not be interpreted as representing
 * official policies, either expressed or implied, of The Regents of the
 * University of California.
 */

#include "mqnic.h"
#include "pspin_ioctl.h"

#include <asm-generic/errno-base.h>
#include <asm-generic/errno.h>
#include <asm/set_memory.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/dma-mapping.h>
#include <linux/err.h>
#include <linux/errno.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/iopoll.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/mutex.h>
#include <linux/slab.h>
#include <linux/stat.h>
#include <linux/uaccess.h>
#include <linux/version.h>

struct pspin_attribute {
  struct kobj_attribute attr;
  u32 idx;                // index of register in block
  u32 offset;             // offset of block
  const char *group_name; // name of the group
  bool (*check_func)(struct device *, u32, u32);
};

#include "regs-gen.h"

MODULE_DESCRIPTION("mqnic pspin driver");
MODULE_AUTHOR("Pengcheng Xu");
MODULE_LICENSE("Dual BSD/GPL");
MODULE_VERSION("0.1");

#define PSPIN_DEVICE_NAME "pspin"
#define PSPIN_NUM_CLUSTERS 2

// memory mapping for host access
#define PSPIN_PROG_BASE 0x1d000000UL
#define PSPIN_PROG_SIZE (32 * 1024) // MEM_PROG_SIZE @ pspin_cfg_pkg.sv
#define PSPIN_HND_BASE 0x1c000000UL
#define PSPIN_HND_SIZE (1 * 1024 * 1024) // MEM_HND_SIZE @ pspin_cfg_pkg.sv

#define CHECK_RANGE(addr, area)                                                \
  ((addr) >= (PSPIN_##area##_BASE) &&                                          \
   (addr) < (PSPIN_##area##_BASE) + (PSPIN_##area##_SIZE))
static s64 pspin_addr_to_corundum(u64 pspin_addr) {
  s64 ret = -1;
  if (CHECK_RANGE(pspin_addr, PROG))
    ret = pspin_addr - PSPIN_PROG_BASE + 0x400000;
  else if (CHECK_RANGE(pspin_addr, HND))
    ret = pspin_addr - PSPIN_HND_BASE;
  return ret;
}

#define NUM_HPUS_PER_CLUSTER 8
#define NUM_HPUS (NUM_HPUS_PER_CLUSTER * PSPIN_NUM_CLUSTERS)

#define REG(app, offset) ((app)->app_hw_addr + 0x800000 + (offset))
#define PSPIN_MEM(app, off) ((app)->app_hw_addr + (off))

#define REG_ADDR(app, name, _idx)                                              \
  REG(app, ATTR_REG_ADDR(attr_to_pspin_attr(ag_##name.attrs[_idx])))
#define ATTR_REG_ADDR(_pspin_attr)                                             \
  (_pspin_attr)->offset + (_pspin_attr)->idx * 4

#define kattr_to_pspin_attr(_attr)                                             \
  container_of(_attr, struct pspin_attribute, attr)
#define attr_to_pspin_attr(_attr)                                              \
  kattr_to_pspin_attr(container_of(_attr, struct kobj_attribute, attr))

static bool check_cl_ctrl(struct device *dev, u32 idx, u32 reg) {
  u32 clusters = reg ? 32 - __builtin_clz(reg) : 0;
  struct mqnic_app_pspin *app = dev->driver_data;
  if (idx != 0 && reg > 1) {
    dev_err(dev, "reset only takes 0 or 1; got %u\n", reg);
    return false;
  } else if (clusters > PSPIN_NUM_CLUSTERS) {
    dev_err(dev, "%d clusters exist, got %d to enable (reg = %#x)\n",
            PSPIN_NUM_CLUSTERS, clusters, reg);
    return false;
  }
  // FIXME: ideally after setting the register
  if (idx != 0) {
    app->in_reset = !!reg;
  }
  return true;
}

static bool check_me_en(struct device *dev, u32 idx, u32 reg) {
  struct mqnic_app_pspin *app = dev->driver_data;

  if (!reg) {
    app->in_me_conf = true;
  } else {
    // TODO: check ME configuration sanity
    app->in_me_conf = false;
  }

  // barrier for enable toggle
  wmb();
  return true;
}

static bool check_her_en(struct device *dev, u32 idx, u32 reg) {
  struct mqnic_app_pspin *app = dev->driver_data;
  int i;

  if (!reg) {
    app->in_her_conf = true;
  } else {
    for (i = 0; i < HER_NUM_HANDLER_CTX; ++i) {
      u64 hostdma_addr, hostdma_size;
      struct ctx_dma_area *phys_area = &app->dma_areas[i].phys;
      bool enabled = phys_area->enabled;
      dma_addr_t handle = phys_area->dma_handle;
      u64 size = phys_area->dma_size;

      hostdma_addr = ioread32(REG_ADDR(app, her_meta_host_mem_addr_0, i));
      hostdma_addr += (u64)ioread32(REG_ADDR(app, her_meta_host_mem_addr_1, i))
                      << 32;
      hostdma_size = ioread32(REG_ADDR(app, her_meta_host_mem_size, i));

      // DMA region must be registered & mapped over ioctl before HER enablement
      if (enabled && (hostdma_addr != handle || hostdma_size != size)) {
        dev_err(dev, "HER %d: trying to set hostdma incorrectly\n", i);
        dev_err(dev,
                "configured: addr=%#llx size=%lld; requested: addr=%#llx, "
                "size=%llx\n",
                handle, size, hostdma_addr, hostdma_size);
        return false;
      }

      // TODO: check that if ME is not in SLMP, prohibit HH and TH (packet mode)
    }
    app->in_her_conf = false;
  }

  // barrier for enable toggle
  wmb();
  return true;
}

static bool check_me_in_conf(struct device *dev, u32 idx, u32 reg) {
  struct mqnic_app_pspin *app = dev->driver_data;

  if (!app->in_me_conf) {
    dev_err(dev, "ME engine in configuration; disable first");
    return false;
  }
  return true;
}

static bool check_her_in_conf(struct device *dev, u32 idx, u32 reg) {
  struct mqnic_app_pspin *app = dev->driver_data;

  if (!app->in_her_conf) {
    dev_err(dev, "HER engine in configuration; disable first");
    return false;
  }
  return true;
}

static ssize_t pspin_reg_store(struct kobject *dir, struct kobj_attribute *attr,
                               const char *buf, size_t count) {
  struct device *dev = container_of(dir->parent, struct device, kobj);
  struct mqnic_app_pspin *app = dev_get_drvdata(dev);
  struct pspin_attribute *dev_attr = kattr_to_pspin_attr(attr);
  u32 off = ATTR_REG_ADDR(dev_attr);
  u32 reg = 0;
  sscanf(buf, "%u\n", &reg);
  if (dev_attr->check_func && !dev_attr->check_func(dev, dev_attr->idx, reg)) {
    dev_err(dev, "check failed for %s%s\n", dev_attr->group_name,
            attr->attr.name);
    return -EINVAL;
  }
  iowrite32(reg, REG(app, off));
  return count;
}

static ssize_t pspin_reg_show(struct kobject *dir, struct kobj_attribute *attr,
                              char *buf) {
  struct device *dev = container_of(dir->parent, struct device, kobj);
  struct mqnic_app_pspin *app = dev_get_drvdata(dev);
  struct pspin_attribute *dev_attr = kattr_to_pspin_attr(attr);
  u32 off = ATTR_REG_ADDR(dev_attr);
  return scnprintf(buf, PAGE_SIZE, "%u\n", ioread32(REG(app, off)));
}
// one per char device (total 2)
struct pspin_cdev {
  enum {
    TY_MEM,
    TY_FIFO,
  } type;
  struct mqnic_app_pspin *app;
  unsigned char *block_buffer;
  struct mutex pspin_mutex; // only locked during memory load (not mmap)
  bool exiting;
  struct cdev cdev;
  struct device *dev;
};

// one per open file - shared across fork
struct pspin_map_data {
  struct pspin_cdev *cdev;
  int ctx_id;
};

static int pspin_ndevices = 2;
static unsigned long pspin_block_size = 4096;
// only checked for mem, stdout is assumed to be unbounded
// XXX: actually larger than memory!
// TODO: check for holes
static unsigned long pspin_mem_size = 0x800000;

static unsigned int pspin_major = 0;
static struct pspin_cdev *pspin_cdevs = NULL;
static struct class *pspin_class = NULL;

static int pspin_open(struct inode *inode, struct file *filp) {
  unsigned mj = imajor(inode);
  unsigned mn = iminor(inode);

  struct pspin_cdev *dev = NULL;
  struct device *d;

  if (mj != pspin_major || mn < 0 || mn >= pspin_ndevices) {
    printk(KERN_WARNING "No character device found with %d:%d\n", mj, mn);
    return -ENODEV;
  }

  dev = &pspin_cdevs[mn];
  filp->private_data = dev;
  d = dev->dev;

  if (inode->i_cdev != &dev->cdev) {
    dev_warn(d, "open: internal error\n");
    return -ENODEV;
  }

  if (dev->block_buffer == NULL) {
    dev->block_buffer =
        (unsigned char *)devm_kzalloc(d, pspin_block_size, GFP_KERNEL);
    if (dev->block_buffer == NULL) {
      dev_warn(d, "open: out of memory\n");
      return -ENOMEM;
    }
  }
  return 0;
}

DECLARE_WAIT_QUEUE_HEAD(stdout_read_queue);
static ssize_t pspin_read(struct file *filp, char __user *buf, size_t count,
                          loff_t *f_pos) {
  struct pspin_cdev *dev = filp->private_data;
  struct mqnic_app_pspin *app = dev->app;
  ssize_t retval = 0;
  int i;

  // prevent operation on mem if in reset
  if (dev->type == TY_MEM && dev->app->in_reset) {
    dev_warn(dev->dev, "PsPIN cluster in reset, rejecting\n");
    return -EPERM;
  }

  if (dev->exiting) {
    return -ENODEV;
  }

  if (mutex_lock_killable(&dev->pspin_mutex))
    return -EINTR;
  if (dev->type == TY_MEM && *f_pos >= pspin_mem_size)
    goto out;
  if (dev->type == TY_MEM && *f_pos + count > pspin_mem_size)
    count = pspin_mem_size - *f_pos;
  if (count > pspin_block_size)
    count = pspin_block_size;
  if (dev->type == TY_MEM)
    count = round_down(count, 4);

  if (dev->type == TY_MEM) {
    for (i = 0; i < count; i += 4) {
      *((u32 *)&dev->block_buffer[i]) = ioread32(PSPIN_MEM(app, *f_pos + i));
    }
    retval = count;
  } else {
    u32 reg;
    uintptr_t off = 0;

    // TODO: demultiplex stdout stream in kernel (and use dedicated pspin_stdout
    // device) with deferred work

    while (off < pspin_block_size) {
      if (dev->exiting) {
        retval = -EINTR;
        goto out;
      }
      retval = wait_event_interruptible_timeout(
          stdout_read_queue, (reg = ioread32(REG_ADDR(app, cl_fifo, 0))) != ~0,
          usecs_to_jiffies(50));
      if (retval == -ERESTARTSYS) // interrupted by signal
        goto out;
      else if (!retval) {
        // timeout expired
        if (!off) {
          // we haven't read anything yet - don't trigger EOF
          continue;
        } else {
          // we got some data - short read
          break;
        }
      }
      // we got data on time
      *((u32 *)&dev->block_buffer[off]) = reg;
      off += 4;
    }

    retval = off;
  }

  if (copy_to_user(buf, dev->block_buffer, retval) != 0) {
    retval = -EFAULT;
    goto out;
  }

  if (dev->type == TY_MEM)
    *f_pos += retval;
out:
  mutex_unlock(&dev->pspin_mutex);
  return retval;
}

static ssize_t pspin_write(struct file *filp, const char __user *buf,
                           size_t count, loff_t *f_pos) {
  struct pspin_cdev *dev = filp->private_data;
  struct mqnic_app_pspin *app = dev->app;
  ssize_t retval = 0;
  int i;

  if (dev->type == TY_FIFO) {
    return -EINVAL;
  }

  // prevent operation on mem if in reset
  if (dev->type == TY_MEM && dev->app->in_reset) {
    dev_warn(dev->dev, "PsPIN cluster in reset, rejecting\n");
    return -EPERM;
  }

  if (mutex_lock_killable(&dev->pspin_mutex))
    return -EINTR;

  if (*f_pos >= pspin_mem_size) {
    retval = -EINVAL;
    goto out;
  }

  if (*f_pos + count > pspin_mem_size)
    count = pspin_mem_size - *f_pos;
  if (count > pspin_block_size)
    count = pspin_block_size;
  count = round_down(count, 4);

  if (copy_from_user(dev->block_buffer, buf, count) != 0) {
    retval = -EFAULT;
    goto out;
  }

  for (i = 0; i < count; i += 4) {
    iowrite32(*((u32 *)&dev->block_buffer[i]), PSPIN_MEM(app, *f_pos + i));
  }
  *f_pos += count;
  retval = count;

out:
  mutex_unlock(&dev->pspin_mutex);
  return retval;
}

static loff_t pspin_llseek(struct file *filp, loff_t off, int whence) {
  struct pspin_cdev *dev = filp->private_data;
  loff_t newpos = 0;

  if (dev->type == TY_FIFO) {
    dev_warn(dev->dev, "stdout FIFO does not support seeking\n");
    return -EINVAL;
  }

  // prevent operation on mem if in reset
  if (dev->type == TY_MEM && dev->app->in_reset) {
    dev_warn(dev->dev, "PsPIN cluster in reset, rejecting\n");
    return -EPERM;
  }

  switch (whence) {
  case SEEK_SET:
    if ((newpos = pspin_addr_to_corundum(off)) < 0) {
      dev_err(dev->dev, "seeking to non-existent PsPIN memory %#llx\n", off);
      return -EINVAL;
    }
    break;
  case SEEK_CUR:
    newpos = filp->f_pos + off;
    break;
  case SEEK_END:
    newpos = pspin_mem_size + off;
    break;
  default: // not supported
    return -EINVAL;
  }
  if (newpos < 0 || newpos > pspin_mem_size) {
    dev_warn(dev->dev,
             "seek outside bounds: newpos=%#llx pspin_mem_size=%#lx\n", newpos,
             pspin_mem_size);
    return -EINVAL;
  }
  filp->f_pos = newpos;
  return newpos;
}

static long pspin_ioctl(struct file *filp, unsigned int cmd,
                        unsigned long arg) {
  struct pspin_cdev *cdev = filp->private_data;
  struct device *dev = cdev->dev;
  struct mqnic_app_pspin *app = cdev->app;
  struct pspin_ioctl_msg *user_ptr = (struct pspin_ioctl_msg *)arg;

  int ctx_id;
  u64 addr, data;
  s64 corundum_addr;

  if (cdev->type == TY_FIFO) {
    return -ENOTTY;
  }

  switch (cmd) {
  case PSPIN_HOSTDMA_QUERY:
    if (copy_from_user(&ctx_id, &user_ptr->query.req.ctx_id, sizeof(int))) {
      dev_err(dev, "read ctx_id error\n");
      return -EFAULT;
    }
    if (ctx_id >= HER_NUM_HANDLER_CTX) {
      dev_err(dev, "invalid ctx_id %d; max %d\n", ctx_id, HER_NUM_HANDLER_CTX);
      return -EINVAL;
    }
    if (copy_to_user(&user_ptr->query.resp, &app->dma_areas[ctx_id].phys,
                     sizeof(struct ctx_dma_area))) {
      dev_err(dev, "write dma area error\n");
      return -EFAULT;
    }
    break;
  case PSPIN_HOST_WRITE:
    if (copy_from_user(&addr, &user_ptr->write.addr, sizeof(u64))) {
      dev_err(dev, "read flag error\n");
      return -EFAULT;
    }
    if ((corundum_addr = pspin_addr_to_corundum(addr)) < 0) {
      dev_err(dev, "trying to access non-existent PsPIN memory %#llx\n", addr);
      return -EFAULT;
    }
    if (copy_from_user(&data, &user_ptr->write.data, sizeof(u64))) {
      dev_err(dev, "read flag error\n");
      return -EFAULT;
    }
    iowrite64_lo_hi(data, PSPIN_MEM(app, corundum_addr));
    break;
  case PSPIN_HOST_READ:
    if (copy_from_user(&addr, &user_ptr->read.word, sizeof(u64))) {
      dev_err(dev, "read addr error\n");
      return -EFAULT;
    }
    if ((corundum_addr = pspin_addr_to_corundum(addr)) < 0) {
      dev_err(dev, "trying to access non-existent PsPIN memory %#llx\n", addr);
      return -EFAULT;
    }
    data = ioread64_lo_hi(PSPIN_MEM(app, corundum_addr));
    if (copy_to_user(&user_ptr->read.word, &data, sizeof(u64))) {
      dev_err(dev, "write data error\n");
      return -EFAULT;
    }
    break;

  default:
    dev_dbg(dev, "unknwon ioctl %d\n", cmd);
    return -ENOTTY;
  }

  return 0;
}

static void pspin_vma_open(struct vm_area_struct *vma) {
  struct pspin_map_data *map_data = vma->vm_private_data;
  struct pspin_cdev *cdev = map_data->cdev;
  struct dma_area_int *area = &cdev->app->dma_areas[map_data->ctx_id];
  // duplicated mapping should always be enabled

  if (!area->phys.enabled) {
    dev_warn(cdev->dev, "vma_open called on inactive area\n");
  }
  ++area->ref_count;

  dev_info(cdev->dev, "%s(): ctx_id %d refcount %d\n", __func__,
           map_data->ctx_id, area->ref_count);
}

static int pspin_vma_may_split(struct vm_area_struct *vma, unsigned long addr) {
  // never allow splitting of the host dma vma
  return -EINVAL;
}

static void pspin_vma_close(struct vm_area_struct *vma) {
  struct pspin_map_data *map_data = vma->vm_private_data;
  struct pspin_cdev *cdev = map_data->cdev;
  struct dma_area_int *area = &cdev->app->dma_areas[map_data->ctx_id];
  unsigned long len = vma->vm_end - vma->vm_start;
  int num_pages = len / PAGE_SIZE;

  if (!area->ref_count) {
    dev_warn(cdev->dev, "trying to decrement ref_count below 0\n");
    return;
  }
  --area->ref_count;
  if (!area->ref_count) {
    if (area->phys.enabled) {
      dev_info(cdev->dev, "freeing hostdma area for ctx %d\n",
               map_data->ctx_id);
      set_memory_wb((u64)area->cpu_addr, num_pages);
      dma_free_coherent(cdev->app->nic_dev, area->phys.dma_size, area->cpu_addr,
                        area->phys.dma_handle);
      area->phys.enabled = false;
    } else {
      dev_warn(cdev->dev, "vma_close called on already inactive area\n");
    }
  }

  dev_info(cdev->dev, "%s(): ctx_id %d refcount %d\n", __func__,
           map_data->ctx_id, area->ref_count);
}

// we do not eagerly unmap - mmap should retain even when file is closed
static int pspin_release(struct inode *inode, struct file *filp) { return 0; }

static struct vm_operations_struct pspin_vm_ops = {
    .open = pspin_vma_open,
    .close = pspin_vma_close,
    .may_split = pspin_vma_may_split,
};

static int pspin_mmap(struct file *filp, struct vm_area_struct *vma) {
  struct pspin_cdev *cdev = filp->private_data;
  struct device *dev = cdev->dev;
  struct mqnic_app_pspin *app = cdev->app;
  struct pspin_map_data *map_data;

  unsigned long len = vma->vm_end - vma->vm_start;
  int num_pages_requested = len / PAGE_SIZE;
  int ctx_id = vma->vm_pgoff / num_pages_requested;
  struct dma_area_int *area;

  if (ctx_id >= HER_NUM_HANDLER_CTX) {
    dev_err(dev, "dma ctx_id too large: %d; total %d\n", ctx_id,
            HER_NUM_HANDLER_CTX);
    return -EINVAL;
  }
  if (!(vma->vm_flags & VM_SHARED)) {
    dev_err(dev, "host dma page must be mapped shared\n");
    return -EINVAL;
  }

  area = &app->dma_areas[ctx_id];

  map_data = devm_kzalloc(dev, sizeof(struct pspin_map_data), GFP_KERNEL);
  if (!map_data) {
    dev_err(dev, "failed to allocate mapping data\n");
    return -ENOMEM;
  }
  map_data->ctx_id = ctx_id;
  map_data->cdev = cdev;

  vma->vm_ops = &pspin_vm_ops;
  vma->vm_flags |= VM_IO;
  vma->vm_private_data = map_data;
  vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);

  // allocate DMA buffer
  if (!area->phys.enabled) {
    area->phys.dma_size = num_pages_requested * PAGE_SIZE;
    area->cpu_addr =
        dma_alloc_coherent(app->nic_dev, area->phys.dma_size,
                           &area->phys.dma_handle, GFP_KERNEL | __GFP_ZERO);
    if (!area->cpu_addr) {
      dev_err(dev, "failed to allocate hostdma buffer\n");
      return -ENOMEM;
    }
    area->phys.enabled = true;

    dev_info(dev,
             "allocated host dma region virt %#llx, dma %#llx, phys %#llx, "
             "size %lld for ctx %d\n",
             (u64)area->cpu_addr, area->phys.dma_handle,
             virt_to_phys(area->cpu_addr), area->phys.dma_size, ctx_id);
  } else {
    // in use by another process
    dev_err(dev, "ctx %d hostdma already in use\n", ctx_id);
    return -EAGAIN;
  }

  // map into user
  // https://stackoverflow.com/questions/9890728/how-would-one-prevent-mmap-from-caching-values
  // https://stackoverflow.com/questions/53196359/mmap-dma-memory-uncached-map-pfn-ram-range-req-uncached-minus-got-write-back
  // FIXME: figure out is uncached the right thing to do (or e.g. write
  // combine?)
  set_memory_uc((u64)area->cpu_addr, num_pages_requested);
  if (vm_iomap_memory(vma, virt_to_phys(area->cpu_addr), len)) {
    dev_err(dev, "failed to map dma region into user\n");
    return -EIO;
  }
  dev_info(dev, "mapped into user at %#llx\n", (u64)vma->vm_start);

  // ref counting
  pspin_vma_open(vma);

  return 0;
}

struct file_operations pspin_fops = {
    .owner = THIS_MODULE,
    .read = pspin_read,
    .write = pspin_write,
    .open = pspin_open,
    .release = pspin_release,
    .llseek = pspin_llseek,
    .unlocked_ioctl = pspin_ioctl,
    .mmap = pspin_mmap,
};

static int pspin_construct_device(struct pspin_cdev *dev, int minor,
                                  struct class *class,
                                  struct mqnic_app_pspin *app) {
  int err = 0;
  dev_t devno = MKDEV(pspin_major, minor);

  BUG_ON(dev == NULL || class == NULL);
  BUG_ON(minor < 0 || minor >= 2);

  dev->block_buffer = NULL;
  dev->app = app;
  mutex_init(&dev->pspin_mutex);
  dev->exiting = false;
  cdev_init(&dev->cdev, &pspin_fops);
  dev->cdev.owner = THIS_MODULE;
  dev->type = minor == 0 ? TY_MEM : TY_FIFO;

  err = cdev_add(&dev->cdev, devno, 1);
  if (err) {
    printk(KERN_WARNING "error %d while trying to add %s%d", err,
           PSPIN_DEVICE_NAME, minor);
    return err;
  }

  dev->dev =
      device_create(class, NULL, devno, NULL, PSPIN_DEVICE_NAME "%d", minor);
  if (IS_ERR(dev->dev)) {
    err = PTR_ERR(dev->dev);
    printk(KERN_WARNING "error %d while trying to create %s%d", err,
           PSPIN_DEVICE_NAME, minor);
    cdev_del(&dev->cdev);
    return err;
  }
  return 0;
}

static void pspin_destroy_device(struct pspin_cdev *dev, int minor,
                                 struct class *class) {
  BUG_ON(dev == NULL || class == NULL);
  BUG_ON(minor < 0 || minor >= 2);

  // block future pspin_read
  dev->exiting = true;

  // wait for already running pspin_read
  mutex_lock(&dev->pspin_mutex);

  device_destroy(class, MKDEV(pspin_major, minor));
  cdev_del(&dev->cdev);
  mutex_destroy(&dev->pspin_mutex);
}

static void pspin_cleanup_chrdev(int devices_to_destroy) {
  int i;

  if (pspin_cdevs) {
    for (i = 0; i < devices_to_destroy; ++i)
      pspin_destroy_device(&pspin_cdevs[i], i, pspin_class);
  }

  if (pspin_class)
    class_destroy(pspin_class);

  unregister_chrdev_region(MKDEV(pspin_major, 0), pspin_ndevices);
}

static int mqnic_app_pspin_probe(struct auxiliary_device *adev,
                                 const struct auxiliary_device_id *id) {
  struct mqnic_dev *mdev = container_of(adev, struct mqnic_adev, adev)->mdev;
  struct device *dev = &adev->dev;

  struct mqnic_app_pspin *app;

  int err = 0;
  int i = 0;
  int devices_to_destroy = 0;
  dev_t devno = 0;

  dev_info(dev, "%s() called", __func__);

  if (!mdev->hw_addr || !mdev->app_hw_addr) {
    dev_err(dev,
            "Error: required region not present: hw_addr %p, app_hw_addr %p\n",
            mdev->hw_addr, mdev->app_hw_addr);
    return -EIO;
  }

  app = devm_kzalloc(dev, sizeof(*app), GFP_KERNEL);
  if (!app)
    return -ENOMEM;

  app->dev = dev;
  dev->driver_data = app;
  app->mdev = mdev;
  dev_set_drvdata(&adev->dev, app);

  app->nic_dev = mdev->dev;
  app->nic_hw_addr = mdev->hw_addr;
  app->app_hw_addr = mdev->app_hw_addr;
  app->ram_hw_addr = mdev->ram_hw_addr;

  // device started up in reset
  app->in_reset = true;

  // HER and ME not configured yet
  app->in_her_conf = true;
  app->in_me_conf = true;

  // setup character special devices
  if (pspin_ndevices <= 0) {
    printk(KERN_WARNING "invalid value of pspin_ndevices: %d\n",
           pspin_ndevices);
    return -EINVAL;
  }

  err = alloc_chrdev_region(&devno, 0, pspin_ndevices, PSPIN_DEVICE_NAME);
  if (err < 0) {
    printk(KERN_WARNING "alloc_chrdev_region() failed\n");
    return err;
  }
  pspin_major = MAJOR(devno);

  pspin_class = class_create(THIS_MODULE, PSPIN_DEVICE_NAME);
  if (IS_ERR(pspin_class)) {
    err = PTR_ERR(pspin_class);
    goto fail;
  }

  pspin_cdevs =
      devm_kzalloc(dev, pspin_ndevices * sizeof(struct pspin_cdev), GFP_KERNEL);
  if (pspin_cdevs == NULL) {
    err = -ENOMEM;
    goto fail;
  }

  for (i = 0; i < pspin_ndevices; ++i) {
    err = pspin_construct_device(&pspin_cdevs[i], i, pspin_class, app);
    if (err) {
      devices_to_destroy = i;
      goto fail;
    }
  }
  devices_to_destroy = pspin_ndevices;

  err = init_pspin_sysfs(app);
  if (err)
    goto fail;

  // bring datapath out of reset
  iowrite32(0, REG_ADDR(app, cl_ctrl, 1));
  app->in_reset = false;

  // reset ME to bypass
  for (i = 0; i < UMATCH_RULESETS * UMATCH_ENTRIES; ++i) {
    iowrite32(htonl(1), REG_ADDR(app, me_start, i));
  }
  iowrite32(1, REG_ADDR(app, me_valid, 0));
  app->in_me_conf = false;

  return 0;

fail:
  pspin_cleanup_chrdev(devices_to_destroy);
  return err;
}

static void mqnic_app_pspin_remove(struct auxiliary_device *adev) {
  struct mqnic_app_pspin *app = dev_get_drvdata(&adev->dev);
  struct device *dev = app->dev;

  dev_info(dev, "%s() called", __func__);

  pspin_cleanup_chrdev(pspin_ndevices);
}

static const struct auxiliary_device_id mqnic_app_pspin_id_table[] = {
    {.name = "mqnic.app_12340100"},
    {},
};

MODULE_DEVICE_TABLE(auxiliary, mqnic_app_pspin_id_table);

static struct auxiliary_driver mqnic_app_pspin_driver = {
    .name = "mqnic_app_pspin",
    .probe = mqnic_app_pspin_probe,
    .remove = mqnic_app_pspin_remove,
    .id_table = mqnic_app_pspin_id_table,
};

static int __init mqnic_app_pspin_init(void) {
  return auxiliary_driver_register(&mqnic_app_pspin_driver);
}

static void __exit mqnic_app_pspin_exit(void) {
  auxiliary_driver_unregister(&mqnic_app_pspin_driver);
}

module_init(mqnic_app_pspin_init);
module_exit(mqnic_app_pspin_exit);
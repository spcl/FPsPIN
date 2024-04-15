/* Generated on 2023-08-25 20:39:06.660412 with: ./regs-compiler.py regs-gen.h ../modules/mqnic_app_pspin/ */

#ifndef __FPSPIN_REGS_GEN_H__
#define __FPSPIN_REGS_GEN_H__
#define UMATCH_WIDTH 32
#define UMATCH_ENTRIES 4
#define UMATCH_RULESETS 4
#define UMATCH_MODES 2
#define HER_NUM_HANDLER_CTX 4

struct mqnic_app_pspin {
  struct device *dev;
  struct mqnic_dev *mdev;
  struct mqnic_adev *adev;

  struct device *nic_dev;

  void __iomem *nic_hw_addr;
  void __iomem *app_hw_addr;
  void __iomem *ram_hw_addr;

  bool in_reset;
  bool in_her_conf;
  bool in_me_conf;

  struct dma_area_int {
    void *cpu_addr;
    struct ctx_dma_area phys;
    int ref_count;
  } dma_areas[HER_NUM_HANDLER_CTX];
};

// FIXME: move into app data?
static struct kobject *dir_cl;
static struct attribute_group ag_cl_ctrl;
static struct attribute_group ag_cl_fifo;
static struct kobject *dir_stats;
static struct attribute_group ag_stats_cluster;
static struct attribute_group ag_stats_mpq;
static struct attribute_group ag_stats_datapath;
static struct kobject *dir_me;
static struct attribute_group ag_me_valid;
static struct attribute_group ag_me_mode;
static struct attribute_group ag_me_idx;
static struct attribute_group ag_me_mask;
static struct attribute_group ag_me_start;
static struct attribute_group ag_me_end;
static struct kobject *dir_her;
static struct attribute_group ag_her_valid;
static struct attribute_group ag_her_ctx_enabled;
static struct kobject *dir_her_meta;
static struct attribute_group ag_her_meta_handler_mem_addr;
static struct attribute_group ag_her_meta_handler_mem_size;
static struct attribute_group ag_her_meta_host_mem_addr_0;
static struct attribute_group ag_her_meta_host_mem_addr_1;
static struct attribute_group ag_her_meta_host_mem_size;
static struct attribute_group ag_her_meta_hh_addr;
static struct attribute_group ag_her_meta_hh_size;
static struct attribute_group ag_her_meta_ph_addr;
static struct attribute_group ag_her_meta_ph_size;
static struct attribute_group ag_her_meta_th_addr;
static struct attribute_group ag_her_meta_th_size;
static struct attribute_group ag_her_meta_scratchpad_0_addr;
static struct attribute_group ag_her_meta_scratchpad_0_size;
static struct attribute_group ag_her_meta_scratchpad_1_addr;
static struct attribute_group ag_her_meta_scratchpad_1_size;
static struct attribute_group ag_her_meta_scratchpad_2_addr;
static struct attribute_group ag_her_meta_scratchpad_2_size;
static struct attribute_group ag_her_meta_scratchpad_3_addr;
static struct attribute_group ag_her_meta_scratchpad_3_size;

static bool check_cl_ctrl(struct device *dev, u32 idx, u32 reg);
static bool check_me_en(struct device *dev, u32 idx, u32 reg);
static bool check_her_en(struct device *dev, u32 idx, u32 reg);
static bool check_me_in_conf(struct device *dev, u32 idx, u32 reg);
static bool check_her_in_conf(struct device *dev, u32 idx, u32 reg);

static ssize_t pspin_reg_show(struct kobject *dir, struct kobj_attribute *attr,
                              char *buf);
static ssize_t pspin_reg_store(struct kobject *dir,
                               struct kobj_attribute *attr, const char *buf,
                               size_t count);

static void remove_pspin_sysfs(void *data) {
  sysfs_remove_group(dir_cl, &ag_cl_ctrl);
  sysfs_remove_group(dir_cl, &ag_cl_fifo);
  kobject_put(dir_cl);
  sysfs_remove_group(dir_stats, &ag_stats_cluster);
  sysfs_remove_group(dir_stats, &ag_stats_mpq);
  sysfs_remove_group(dir_stats, &ag_stats_datapath);
  kobject_put(dir_stats);
  sysfs_remove_group(dir_me, &ag_me_valid);
  sysfs_remove_group(dir_me, &ag_me_mode);
  sysfs_remove_group(dir_me, &ag_me_idx);
  sysfs_remove_group(dir_me, &ag_me_mask);
  sysfs_remove_group(dir_me, &ag_me_start);
  sysfs_remove_group(dir_me, &ag_me_end);
  kobject_put(dir_me);
  sysfs_remove_group(dir_her, &ag_her_valid);
  sysfs_remove_group(dir_her, &ag_her_ctx_enabled);
  kobject_put(dir_her);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_handler_mem_addr);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_handler_mem_size);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_host_mem_addr_0);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_host_mem_addr_1);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_host_mem_size);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_hh_addr);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_hh_size);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_ph_addr);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_ph_size);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_th_addr);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_th_size);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_scratchpad_0_addr);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_scratchpad_0_size);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_scratchpad_1_addr);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_scratchpad_1_size);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_scratchpad_2_addr);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_scratchpad_2_size);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_scratchpad_3_addr);
  sysfs_remove_group(dir_her_meta, &ag_her_meta_scratchpad_3_size);
  kobject_put(dir_her_meta);
}

#define ATTR_NAME_LEN 32
static int init_pspin_sysfs(struct mqnic_app_pspin *app) {
  struct device *dev = app->dev;
  int i, ret;
  struct pspin_attribute *attr;
  dir_cl = kobject_create_and_add("cl", &dev->kobj);
  ag_cl_ctrl.name = "ctrl";
  ag_cl_ctrl.attrs = devm_kcalloc(dev, 3, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 2; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x0;
    attr->group_name = ag_cl_ctrl.name;
    attr->check_func = check_cl_ctrl;
    ag_cl_ctrl.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_cl, &ag_cl_ctrl))) {
    dev_err(dev, "failed to create sysfs subgroup ag_cl_ctrl\n");
    return ret;
  }
  ag_cl_fifo.name = "fifo";
  ag_cl_fifo.attrs = devm_kcalloc(dev, 2, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 1; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0444;
    attr->attr.show = pspin_reg_show;
    attr->idx = i;
    attr->offset = 0x8;
    attr->group_name = ag_cl_fifo.name;
    attr->check_func = NULL;
    ag_cl_fifo.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_cl, &ag_cl_fifo))) {
    dev_err(dev, "failed to create sysfs subgroup ag_cl_fifo\n");
    return ret;
  }

  dir_stats = kobject_create_and_add("stats", &dev->kobj);
  ag_stats_cluster.name = "cluster";
  ag_stats_cluster.attrs = devm_kcalloc(dev, 3, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 2; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0444;
    attr->attr.show = pspin_reg_show;
    attr->idx = i;
    attr->offset = 0x1000;
    attr->group_name = ag_stats_cluster.name;
    attr->check_func = NULL;
    ag_stats_cluster.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_stats, &ag_stats_cluster))) {
    dev_err(dev, "failed to create sysfs subgroup ag_stats_cluster\n");
    return ret;
  }
  ag_stats_mpq.name = "mpq";
  ag_stats_mpq.attrs = devm_kcalloc(dev, 2, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 1; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0444;
    attr->attr.show = pspin_reg_show;
    attr->idx = i;
    attr->offset = 0x1008;
    attr->group_name = ag_stats_mpq.name;
    attr->check_func = NULL;
    ag_stats_mpq.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_stats, &ag_stats_mpq))) {
    dev_err(dev, "failed to create sysfs subgroup ag_stats_mpq\n");
    return ret;
  }
  ag_stats_datapath.name = "datapath";
  ag_stats_datapath.attrs = devm_kcalloc(dev, 3, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 2; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0444;
    attr->attr.show = pspin_reg_show;
    attr->idx = i;
    attr->offset = 0x100c;
    attr->group_name = ag_stats_datapath.name;
    attr->check_func = NULL;
    ag_stats_datapath.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_stats, &ag_stats_datapath))) {
    dev_err(dev, "failed to create sysfs subgroup ag_stats_datapath\n");
    return ret;
  }

  dir_me = kobject_create_and_add("me", &dev->kobj);
  ag_me_valid.name = "valid";
  ag_me_valid.attrs = devm_kcalloc(dev, 2, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 1; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x2000;
    attr->group_name = ag_me_valid.name;
    attr->check_func = check_me_en;
    ag_me_valid.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_me, &ag_me_valid))) {
    dev_err(dev, "failed to create sysfs subgroup ag_me_valid\n");
    return ret;
  }
  ag_me_mode.name = "mode";
  ag_me_mode.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x2004;
    attr->group_name = ag_me_mode.name;
    attr->check_func = check_me_in_conf;
    ag_me_mode.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_me, &ag_me_mode))) {
    dev_err(dev, "failed to create sysfs subgroup ag_me_mode\n");
    return ret;
  }
  ag_me_idx.name = "idx";
  ag_me_idx.attrs = devm_kcalloc(dev, 17, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 16; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x2014;
    attr->group_name = ag_me_idx.name;
    attr->check_func = check_me_in_conf;
    ag_me_idx.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_me, &ag_me_idx))) {
    dev_err(dev, "failed to create sysfs subgroup ag_me_idx\n");
    return ret;
  }
  ag_me_mask.name = "mask";
  ag_me_mask.attrs = devm_kcalloc(dev, 17, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 16; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x2054;
    attr->group_name = ag_me_mask.name;
    attr->check_func = check_me_in_conf;
    ag_me_mask.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_me, &ag_me_mask))) {
    dev_err(dev, "failed to create sysfs subgroup ag_me_mask\n");
    return ret;
  }
  ag_me_start.name = "start";
  ag_me_start.attrs = devm_kcalloc(dev, 17, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 16; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x2094;
    attr->group_name = ag_me_start.name;
    attr->check_func = check_me_in_conf;
    ag_me_start.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_me, &ag_me_start))) {
    dev_err(dev, "failed to create sysfs subgroup ag_me_start\n");
    return ret;
  }
  ag_me_end.name = "end";
  ag_me_end.attrs = devm_kcalloc(dev, 17, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 16; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x20d4;
    attr->group_name = ag_me_end.name;
    attr->check_func = check_me_in_conf;
    ag_me_end.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_me, &ag_me_end))) {
    dev_err(dev, "failed to create sysfs subgroup ag_me_end\n");
    return ret;
  }

  dir_her = kobject_create_and_add("her", &dev->kobj);
  ag_her_valid.name = "valid";
  ag_her_valid.attrs = devm_kcalloc(dev, 2, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 1; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x3000;
    attr->group_name = ag_her_valid.name;
    attr->check_func = check_her_en;
    ag_her_valid.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her, &ag_her_valid))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_valid\n");
    return ret;
  }
  ag_her_ctx_enabled.name = "ctx_enabled";
  ag_her_ctx_enabled.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x3004;
    attr->group_name = ag_her_ctx_enabled.name;
    attr->check_func = check_her_in_conf;
    ag_her_ctx_enabled.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her, &ag_her_ctx_enabled))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_ctx_enabled\n");
    return ret;
  }

  dir_her_meta = kobject_create_and_add("her_meta", &dev->kobj);
  ag_her_meta_handler_mem_addr.name = "handler_mem_addr";
  ag_her_meta_handler_mem_addr.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4000;
    attr->group_name = ag_her_meta_handler_mem_addr.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_handler_mem_addr.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_handler_mem_addr))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_handler_mem_addr\n");
    return ret;
  }
  ag_her_meta_handler_mem_size.name = "handler_mem_size";
  ag_her_meta_handler_mem_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4010;
    attr->group_name = ag_her_meta_handler_mem_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_handler_mem_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_handler_mem_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_handler_mem_size\n");
    return ret;
  }
  ag_her_meta_host_mem_addr_0.name = "host_mem_addr_0";
  ag_her_meta_host_mem_addr_0.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4020;
    attr->group_name = ag_her_meta_host_mem_addr_0.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_host_mem_addr_0.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_host_mem_addr_0))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_host_mem_addr_0\n");
    return ret;
  }
  ag_her_meta_host_mem_addr_1.name = "host_mem_addr_1";
  ag_her_meta_host_mem_addr_1.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4030;
    attr->group_name = ag_her_meta_host_mem_addr_1.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_host_mem_addr_1.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_host_mem_addr_1))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_host_mem_addr_1\n");
    return ret;
  }
  ag_her_meta_host_mem_size.name = "host_mem_size";
  ag_her_meta_host_mem_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4040;
    attr->group_name = ag_her_meta_host_mem_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_host_mem_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_host_mem_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_host_mem_size\n");
    return ret;
  }
  ag_her_meta_hh_addr.name = "hh_addr";
  ag_her_meta_hh_addr.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4050;
    attr->group_name = ag_her_meta_hh_addr.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_hh_addr.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_hh_addr))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_hh_addr\n");
    return ret;
  }
  ag_her_meta_hh_size.name = "hh_size";
  ag_her_meta_hh_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4060;
    attr->group_name = ag_her_meta_hh_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_hh_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_hh_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_hh_size\n");
    return ret;
  }
  ag_her_meta_ph_addr.name = "ph_addr";
  ag_her_meta_ph_addr.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4070;
    attr->group_name = ag_her_meta_ph_addr.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_ph_addr.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_ph_addr))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_ph_addr\n");
    return ret;
  }
  ag_her_meta_ph_size.name = "ph_size";
  ag_her_meta_ph_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4080;
    attr->group_name = ag_her_meta_ph_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_ph_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_ph_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_ph_size\n");
    return ret;
  }
  ag_her_meta_th_addr.name = "th_addr";
  ag_her_meta_th_addr.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4090;
    attr->group_name = ag_her_meta_th_addr.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_th_addr.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_th_addr))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_th_addr\n");
    return ret;
  }
  ag_her_meta_th_size.name = "th_size";
  ag_her_meta_th_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x40a0;
    attr->group_name = ag_her_meta_th_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_th_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_th_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_th_size\n");
    return ret;
  }
  ag_her_meta_scratchpad_0_addr.name = "scratchpad_0_addr";
  ag_her_meta_scratchpad_0_addr.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x40b0;
    attr->group_name = ag_her_meta_scratchpad_0_addr.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_scratchpad_0_addr.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_scratchpad_0_addr))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_scratchpad_0_addr\n");
    return ret;
  }
  ag_her_meta_scratchpad_0_size.name = "scratchpad_0_size";
  ag_her_meta_scratchpad_0_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x40c0;
    attr->group_name = ag_her_meta_scratchpad_0_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_scratchpad_0_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_scratchpad_0_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_scratchpad_0_size\n");
    return ret;
  }
  ag_her_meta_scratchpad_1_addr.name = "scratchpad_1_addr";
  ag_her_meta_scratchpad_1_addr.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x40d0;
    attr->group_name = ag_her_meta_scratchpad_1_addr.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_scratchpad_1_addr.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_scratchpad_1_addr))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_scratchpad_1_addr\n");
    return ret;
  }
  ag_her_meta_scratchpad_1_size.name = "scratchpad_1_size";
  ag_her_meta_scratchpad_1_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x40e0;
    attr->group_name = ag_her_meta_scratchpad_1_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_scratchpad_1_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_scratchpad_1_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_scratchpad_1_size\n");
    return ret;
  }
  ag_her_meta_scratchpad_2_addr.name = "scratchpad_2_addr";
  ag_her_meta_scratchpad_2_addr.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x40f0;
    attr->group_name = ag_her_meta_scratchpad_2_addr.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_scratchpad_2_addr.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_scratchpad_2_addr))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_scratchpad_2_addr\n");
    return ret;
  }
  ag_her_meta_scratchpad_2_size.name = "scratchpad_2_size";
  ag_her_meta_scratchpad_2_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4100;
    attr->group_name = ag_her_meta_scratchpad_2_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_scratchpad_2_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_scratchpad_2_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_scratchpad_2_size\n");
    return ret;
  }
  ag_her_meta_scratchpad_3_addr.name = "scratchpad_3_addr";
  ag_her_meta_scratchpad_3_addr.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4110;
    attr->group_name = ag_her_meta_scratchpad_3_addr.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_scratchpad_3_addr.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_scratchpad_3_addr))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_scratchpad_3_addr\n");
    return ret;
  }
  ag_her_meta_scratchpad_3_size.name = "scratchpad_3_size";
  ag_her_meta_scratchpad_3_size.attrs = devm_kcalloc(dev, 5, sizeof(void *), GFP_KERNEL);
  for (i = 0; i < 4; ++i) {
    char *name_buf = (char *)devm_kzalloc(dev, ATTR_NAME_LEN, GFP_KERNEL);
    scnprintf(name_buf, ATTR_NAME_LEN, "%d", i);
    attr = devm_kzalloc(dev, sizeof(struct pspin_attribute), GFP_KERNEL);
    attr->attr.attr.name = name_buf;
    attr->attr.attr.mode = 0644;
    attr->attr.show = pspin_reg_show;
    attr->attr.store = pspin_reg_store;
    attr->idx = i;
    attr->offset = 0x4120;
    attr->group_name = ag_her_meta_scratchpad_3_size.name;
    attr->check_func = check_her_in_conf;
    ag_her_meta_scratchpad_3_size.attrs[i] = (struct attribute *)attr;
  }
  if ((ret = sysfs_create_group(dir_her_meta, &ag_her_meta_scratchpad_3_size))) {
    dev_err(dev, "failed to create sysfs subgroup ag_her_meta_scratchpad_3_size\n");
    return ret;
  }


  ret = devm_add_action_or_reset(dev, remove_pspin_sysfs, app);
  if (ret) {
    dev_err(dev, "failed to add cleanup action for sysfs nodes\n");
    return ret;
  }

  return ret;
}

#endif
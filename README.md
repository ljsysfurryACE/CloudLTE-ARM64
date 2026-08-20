# ☁️ Cloud LTE OS ARM64

**DeepFurry 移植版** — Linux from Scratch 微型系统，从 x86_64 移植到 **ARM64 (aarch64)**。

面向 **晶晨 A311D**（网心云 OES / Khadas VIM3），定位为**无人机机载 AI 大脑**操作系统。

## ✨ 特性

| 特性 | 说明 |
|------|------|
| 🧠 内核 | Linux **5.4.269** (ARM64) — A311D BSP 匹配，NPU 驱动可用 |
| 📦 体积 | 内核 26MB + initramfs 1.2MB = **迷你系统** |
| ⚡ Shell | BusyBox 1.36.1 (静态编译, ARM64) |
| 🚁 定位 | 飞控机载 AI 大脑 (YOLO 视觉 / MAVLink / 自主飞行) |
| 🧩 芯片 | 晶晨 A311D (4×A73 + 2×A53, 5 TOPS NPU) |

## 📦 文件

| 文件 | 大小 | 说明 |
|------|------|------|
| `Image` | 26MB | Linux 5.4.269 ARM64 内核 |
| `initramfs.gz` | 1.2MB | 最小 rootfs (BusyBox + init) |
| `busybox` | 2.1MB | 静态编译 ARM64 BusyBox |
| `meson-g12b-a311d-khadas-vim3.dtb` | 44K | A311D 设备树 (VIM3) |
| `build.sh` | — | ARM64 交叉编译脚本 |

## 🚀 启动验证 (QEMU 实测通过)

```bash
# 需要: qemu-system-aarch64
qemu-system-aarch64 -M virt -cpu cortex-a53 -m 512 \
  -kernel Image \
  -initrd initramfs.gz \
  -append 'console=ttyAMA0 rdinit=/init panic=-1' \
  -nographic
```

**实测输出**（启动成功，shell 可用）:

```
[1.115649] Run /init as init process

====================
 Cloud LTE OS ARM64
 (Linux 5.4 A311D)
====================
Booting... init OK

~ #                    ← BusyBox shell
```

## 🔨 交叉编译

```bash
# 工具链
apt install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu

# 内核 (5.4.269)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4 Image dtbs

# BusyBox (静态)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j4

# initramfs
cd initramfs && find . | cpio -o -H newc | gzip > /tmp/initramfs.gz
```

## ⚠️ 踩坑记录

1. **内核版本选择**: 用 5.4 (BSP) 而非 7.x — 晶晨闭源驱动 (NPU/GPU) 只支持 5.4
2. **busybox 1.36.1 编译错**: `networking/tc.c` 报 `struct tc_cbq_wrropt` 未定义 → 禁用 `CONFIG_TC`
3. **QEMU 机器**: `-M virt` 不要指定 amlogic dtb (用 QEMU 自动生成); 真实板子才用 dtb
4. **启动慢**: 无 KVM 时 TCG 模拟启动 ~60s, 用 `-smp 2` 加速

## 🎯 Roadmap

- [x] Linux 5.4.269 ARM64 内核 + BusyBox + initramfs 启动链
- [x] QEMU 启动验证 (shell 可用)
- [ ] 网心云 OES 真实设备树 + U-Boot 刷机镜像
- [ ] Python / MAVLink / YOLO 机载 AI 环境
- [ ] 飞控通信 (PX4) 集成

## 许可证

GPL-3.0 © Cloud LTE Studio (与 DeepFurry 一致)

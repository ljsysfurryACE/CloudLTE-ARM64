#!/bin/bash
# Cloud LTE OS ARM64 交叉编译脚本 (DeepFurry 移植版)
# 目标: 晶晨 A311D (网心云 OES / Khadas VIM3)
set -e

ARCH=arm64
CROSS=aarch64-linux-gnu-
KERNEL_VER=5.4.269
KERNEL_URL="https://mirrors.tuna.tsinghua.edu.cn/kernel/v5.x/linux-${KERNEL_VER}.tar.xz"
BUSYBOX_VER=1.36.1
BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VER}.tar.bz2"
DIR=/tmp/cloudlte-arm64-build
OUT=$DIR/output

echo "=== ☁️ Cloud LTE OS ARM64 Build ==="
mkdir -p $DIR $OUT

# 1. 工具链检查
echo "[1/5] 检查交叉编译工具链..."
command -v ${CROSS}gcc >/dev/null || { echo "装工具链: apt install gcc-aarch64-linux-gnu"; exit 1; }
${CROSS}gcc --version | head -1

# 2. 内核
echo "[2/5] 内核 Linux $KERNEL_VER (ARM64)..."
cd $DIR
[ -f linux-${KERNEL_VER}.tar.xz ] || curl -L -o linux-${KERNEL_VER}.tar.xz $KERNEL_URL
[ -d linux-${KERNEL_VER} ] || tar xf linux-${KERNEL_VER}.tar.xz
cd linux-${KERNEL_VER}
if [ ! -f .config ]; then
    make ARCH=$ARCH CROSS_COMPILE=$CROSS defconfig
    # A311D 平台支持
    ./scripts/config -e CONFIG_ARM_AMLOGIC
    ./scripts/config -e CONFIG_MESON_G12A
    ./scripts/config -e CONFIG_MESON_GXL
    ./scripts/config -e CONFIG_INITRAMFS_SOURCE
    # 网络 (飞控 MAVLink)
    ./scripts/config -e CONFIG_NET
    ./scripts/config -e CONFIG_PACKET
    ./scripts/config -e CONFIG_UNIX
fi
echo "  编译内核 (4 核, 约 20-40 分钟)..."
make ARCH=$ARCH CROSS_COMPILE=$CROSS -j4 Image dtbs 2>&1 | tail -3
cp arch/arm64/boot/Image $OUT/
cp arch/arm64/boot/dts/amlogic/meson-g12b-a311d-khadas-vim3.dtb $OUT/ 2>/dev/null || true

# 3. BusyBox
echo "[3/5] BusyBox $BUSYBOX_VER (静态 ARM64)..."
cd $DIR
[ -f busybox-${BUSYBOX_VER}.tar.bz2 ] || curl -L -o busybox-${BUSYBOX_VER}.tar.bz2 $BUSYBOX_URL
[ -d busybox-${BUSYBOX_VER} ] || tar xjf busybox-${BUSYBOX_VER}.tar.bz2
cd busybox-${BUSYBOX_VER}
make ARCH=$ARCH CROSS_COMPILE=$CROSS defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config  # 修复 tc_cbq_wrropt 错误
make ARCH=$ARCH CROSS_COMPILE=$CROSS -j4 2>&1 | tail -3
cp busybox $OUT/

# 4. initramfs
echo "[4/5] initramfs..."
rm -rf $DIR/initramfs && mkdir -p $DIR/initramfs/{bin,dev,proc,sys,etc,mnt,root}
cp $OUT/busybox $DIR/initramfs/bin/
cd $DIR/initramfs/bin
for app in sh ls cat mount umount ps echo mkdir cp mv rm dmesg reboot poweroff; do
    ln -sf busybox $app
done
cat > $DIR/initramfs/init << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
echo ''
echo '===================='
echo ' Cloud LTE OS ARM64'
echo ' (Linux 5.4 A311D)'
echo '===================='
echo 'Booting... init OK'
echo ''
exec /bin/sh
EOF
chmod +x $DIR/initramfs/init
cd $DIR/initramfs && find . | cpio -o -H newc 2>/dev/null | gzip > $OUT/initramfs.gz

# 5. 汇总
echo "[5/5] 输出:"
ls -lh $OUT/
echo ""
echo "=== ✅ Cloud LTE OS ARM64 构建完成 ==="
echo "QEMU 验证:"
echo "  qemu-system-aarch64 -M virt -cpu cortex-a53 -m 512 -kernel $OUT/Image -initrd $OUT/initramfs.gz -append 'console=ttyAMA0 rdinit=/init panic=-1' -nographic"

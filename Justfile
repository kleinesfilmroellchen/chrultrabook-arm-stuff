set export := true

TEMP_DEPTHCHARGE := justfile_directory() / "tmp"
KERNELVERSION := "6.7"
IMAGE := "ArchLinuxARM-oak-latest"
KERNEL_UUID := "1A1BBC68-C801-1A48-AE23-5231DEC1BBF2"
KERNEL_CONFIG := "config-chrultrabook-mt8183.aarch64"

clean:
	-rm -f "{{TEMP_DEPTHCHARGE}}/*"
	mkdir -p {{TEMP_DEPTHCHARGE}}

# Compile the kernel from an existing checkout, using elly’s kukui config.
kernel KERNEL_DIR:
	#!/usr/bin/env bash
	set -euxo pipefail
	cd ${KERNEL_DIR}
	make mrproper
	curl -LO "https://raw.githubusercontent.com/ellyq/board-google-kukui/main/linux/${KERNEL_CONFIG}"
	mv ${KERNEL_CONFIG} .config
	ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- make -j$(nproc)

# Download the (latest) Arch Linux ARM rootfs archive.
download-arch:
	#!/usr/bin/env bash
	set -euxo pipefail
	cd ${TEMP_DEPTHCHARGE}
	rm  ${IMAGE}.tar.gz
	curl -LO http://os.archlinuxarm.org/os/${IMAGE}.tar.gz

# Build a rootfs from the Arch Linux ARM archive.
rootfs:
	#!/usr/bin/env bash
	set -euxo pipefail
	cd ${TEMP_DEPTHCHARGE}
	umount root || true
	rm -rf ${IMAGE}
	rm -f rootfs.img
	mkdir -p ${IMAGE}
	# 2x storage space when inside an ext4 image is a conservative estimate.
	# The image should only be about 2GB in size later.
	needed_size=$(gzip -l ${IMAGE}.tar.gz | awk 'FNR == 2 { print $2 * 2 }')  
	truncate -s ${needed_size} rootfs.img
	mke2fs rootfs.img
	rm -rf root
	mkdir -p root
	fuse2fs -o fakeroot rootfs.img root
	tar -xf ${IMAGE}.tar.gz -C root
	umount root

# Make a new depthcharge-bootable disk image. Parameters: Kernel image, device tree blob directory.
disk TEMP_KERNEL TEMP_DTBS:
	#!/usr/bin/env bash
	set -euxo pipefail
	depthchargectl build -v \
		--board arm64-generic \
		--kernel-release ${KERNELVERSION} \
		--kernel ${TEMP_KERNEL} \
		--fdtdir ${TEMP_DTBS} \
		--initramfs none \
		--root none \
		--kernel-cmdline "--- root=PARTUUID=${KERNEL_UUID}" \
		--output ${TEMP_DEPTHCHARGE}/kernel.img
	# Resize image to rootfs + kernel + buffer size
	# make sure to keep the size sector aligned or depthchargectl will complain!
	NEEDED_IMAGE_SIZE=$(echo "($(stat -c%s "${TEMP_DEPTHCHARGE}/kernel.img") + (20 * 1024 * 1024) + $(stat -c%s "${TEMP_DEPTHCHARGE}/rootfs.img")) / 512 * 512" | bc)
	truncate -s ${NEEDED_IMAGE_SIZE} ${TEMP_DEPTHCHARGE}/disk.img
	# create partitions
	printf "%s\n" \
		"label: gpt" \
		"label-id: FAA8418B-0E21-7B4A-832F-610E4BDB0011" \
		"start=1M, size=$(echo "$(stat '-c%s' "${TEMP_DEPTHCHARGE}/kernel.img") / 512 + 1" | bc), type=FE3A2A5D-4F32-41A7-B725-ACCC3285A309, uuid=1A1BBC68-C801-1A48-AE23-5231DEC1BBF1" \
		"size=+, type=linux, uuid=${KERNEL_UUID}" \
		| sfdisk "${TEMP_DEPTHCHARGE}/disk.img"
	# copy kernel to ChromeOS Kernel partition
	depthchargectl write -v \
		--target "${TEMP_DEPTHCHARGE}/disk.img" \
		"${TEMP_DEPTHCHARGE}/kernel.img"
	# copy rootfs to second partition
	ROOTFS_START_SECTOR=$(fdisk --bytes -o Start -l "${TEMP_DEPTHCHARGE}/disk.img" | tail -n 1 | xargs)
	dd if="${TEMP_DEPTHCHARGE}/rootfs.img" of="${TEMP_DEPTHCHARGE}/disk.img" \
		bs=512 seek=${ROOTFS_START_SECTOR} conv=notrunc
	# save compressed version of the kernel (convenience; uncomment if you don’t have brotli)
	brotli -9j "${TEMP_DEPTHCHARGE}/kernel.img"
	# brotli -9j "${TEMP_DEPTHCHARGE}/disk.img"

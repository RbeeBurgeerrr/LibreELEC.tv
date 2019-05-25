# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2017-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="u-boot"
PKG_ARCH="arm aarch64"
PKG_LICENSE="GPL"
PKG_SITE="https://www.denx.de/wiki/U-Boot"
PKG_DEPENDS_TARGET="toolchain swig:host"
PKG_LONGDESC="Das U-Boot is a cross-platform bootloader for embedded systems."

PKG_IS_KERNEL_PKG="yes"
PKG_STAMP="$UBOOT_SYSTEM"

[ -n "$ATF_PLATFORM" ] && PKG_DEPENDS_TARGET+=" atf"

PKG_NEED_UNPACK="$PROJECT_DIR/$PROJECT/bootloader"
[ -n "$DEVICE" ] && PKG_NEED_UNPACK+=" $PROJECT_DIR/$PROJECT/devices/$DEVICE/bootloader"

case "${PROJECT}-${UBOOT_SYSTEM}" in
  Amlogic-odroid-n2|Amlogic-khadas-vim3)
    PKG_VERSION="7272dbb0b09cc3083edc85368b2ad947bfd210b8" # travis/odroidn2-25
    PKG_SHA256="8ca576d88b31fdfe5b9eb5cdc2e5c6bc2d20c9a354799b8212ece4cc37dd4ddd"
    PKG_URL="https://github.com/hardkernel/u-boot/archive/${PKG_VERSION}.tar.gz"
    PKG_DEPENDS_TARGET+=" gcc-linaro-aarch64-elf:host gcc-linaro-arm-eabi:host"
    ;;
  Amlogic*)
    PKG_VERSION="2019.07-rc1"
    PKG_SHA256="c80166bc77ac60ab60e388c7eee07b2b9aebd407588b430c1e9ebcb8baed7ddc"
    PKG_URL="http://ftp.denx.de/pub/u-boot/u-boot-$PKG_VERSION.tar.bz2"
    ;;
  Rockchip*)
    PKG_VERSION="8659d08d2b589693d121c1298484e861b7dafc4f"
    PKG_SHA256="3f9f2bbd0c28be6d7d6eb909823fee5728da023aca0ce37aef3c8f67d1179ec1"
    PKG_URL="https://github.com/rockchip-linux/u-boot/archive/$PKG_VERSION.tar.gz"
    PKG_PATCH_DIRS="rockchip"
    PKG_DEPENDS_TARGET+=" rkbin"
    PKG_NEED_UNPACK+=" $(get_pkg_directory rkbin)"
    ;;
  *)
    PKG_VERSION="2019.04"
    PKG_SHA256="76b7772d156b3ddd7644c8a1736081e55b78828537ff714065d21dbade229bef"
    PKG_URL="http://ftp.denx.de/pub/u-boot/u-boot-$PKG_VERSION.tar.bz2"
    ;;
esac

case "${PROJECT}" in
  Amlogic)
    PKG_DEPENDS_TARGET+=" amlogic-boot-fip"
    ;;
esac

post_unpack() {
  if [ "$UBOOT_SYSTEM" = "odroid-n2" -o "$UBOOT_SYSTEM" = "khadas-vim3" ]; then
    sed -i "s|arm-none-eabi-|arm-eabi-|g" $PKG_BUILD/Makefile $PKG_BUILD/arch/arm/cpu/armv8/g*/firmware/scp_task/Makefile 2>/dev/null || true
    sed -i "s|export CROSS_COMPILE=aarch64-none-elf-||g" $PKG_BUILD/Makefile || true
  fi
}

post_patch() {
  if [ -n "$UBOOT_SYSTEM" ]; then
    # Enable LZ4, LZO and LZMA decompression support
    echo -e "CONFIG_LZ4=y\nCONFIG_LZO=y\nCONFIG_LZMA=y" >> "$PKG_BUILD/configs/$($ROOT/$SCRIPTS/uboot_helper $PROJECT $DEVICE $UBOOT_SYSTEM config)"
  fi
}

make_target() {
  if [ -z "$UBOOT_SYSTEM" ]; then
    echo "UBOOT_SYSTEM must be set to build an image"
    echo "see './scripts/uboot_helper' for more information"
  else
    [ "${BUILD_WITH_DEBUG}" = "yes" ] && PKG_DEBUG=1 || PKG_DEBUG=0
    [ -n "$ATF_PLATFORM" ] &&  cp -av $(get_build_dir atf)/bl31.bin .
    case "${UBOOT_SYSTEM:-$PROJECT}" in
      odroid-n2|khadas-vim3)
        export PATH=$TOOLCHAIN/lib/gcc-linaro-aarch64-elf/bin/:$TOOLCHAIN/lib/gcc-linaro-arm-eabi/bin/:$PATH
        DEBUG=${PKG_DEBUG} CROSS_COMPILE=aarch64-elf- ARCH=arm CFLAGS="" LDFLAGS="" make mrproper
        DEBUG=${PKG_DEBUG} CROSS_COMPILE=aarch64-elf- ARCH=arm CFLAGS="" LDFLAGS="" make odroidn2_defconfig
        DEBUG=${PKG_DEBUG} CROSS_COMPILE=aarch64-elf- ARCH=arm CFLAGS="" LDFLAGS="" make HOSTCC="$HOST_CC" HOSTSTRIP="true"
        ;;
      *)
        DEBUG=${PKG_DEBUG} CROSS_COMPILE="$TARGET_KERNEL_PREFIX" LDFLAGS="" ARCH=arm make mrproper
        DEBUG=${PKG_DEBUG} CROSS_COMPILE="$TARGET_KERNEL_PREFIX" LDFLAGS="" ARCH=arm make $($ROOT/$SCRIPTS/uboot_helper $PROJECT $DEVICE $UBOOT_SYSTEM config)
        DEBUG=${PKG_DEBUG} CROSS_COMPILE="$TARGET_KERNEL_PREFIX" LDFLAGS="" ARCH=arm _python_sysroot="$TOOLCHAIN" _python_prefix=/ _python_exec_prefix=/ make HOSTCC="$HOST_CC" HOSTLDFLAGS="-L$TOOLCHAIN/lib" HOSTSTRIP="true" CONFIG_MKIMAGE_DTC_PATH="scripts/dtc/dtc"
    esac
  fi
}

makeinstall_target() {
  mkdir -p $INSTALL/usr/share/bootloader

    # Only install u-boot.img et al when building a board specific image
    if [ -n "$UBOOT_SYSTEM" ]; then
      find_file_path bootloader/install && . ${FOUND_PATH}
    fi

    # Always install the update script
    find_file_path bootloader/update.sh && cp -av ${FOUND_PATH} $INSTALL/usr/share/bootloader

    # Always install the canupdate script
    if find_file_path bootloader/canupdate.sh; then
      cp -av ${FOUND_PATH} $INSTALL/usr/share/bootloader
      sed -e "s/@PROJECT@/${DEVICE:-$PROJECT}/g" -i $INSTALL/usr/share/bootloader/canupdate.sh
    fi

    # Install boot.ini if it exists
    if find_file_path bootloader/${UBOOT_SYSTEM}.ini; then
      cp -av ${FOUND_PATH} $INSTALL/usr/share/bootloader/boot.ini
    fi
}

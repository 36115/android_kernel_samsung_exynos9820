#!/bin/bash

separator ()
{
  echo "---------------------------------------------------------"
}

quotes () 
{
  echo "-- $1..."
}

noquotes () 
{
  echo "-- $1"
}

clean ()
{
    separator
    quotes "Cleanup Build Files"

    cd $DIR && rm -rf o* .w* build/AIK/s* build/AIK/ramdisk/f* build/*.p* build/*er* arch/arm64/configs/k* && git restore arch/arm64/configs/$KERNEL_DEFCONFIG

    if [[ "$CLEAN" == "y" ]]; then
        separator
        quotes "Revert all Change to Latest Commit (All Uncommit Change will Lost!)"
        separator
        rm -rf K* toolc* build/A* build/d* build/m* build/s* build/u* && git clean -df && git reset --hard HEAD
    fi
}

abort ()
{
    cd -

    if [[ "$LOCAL" == "y" ]]; then
        clean
    fi

    separator
    quotes "Failed to Compile Kernel! Exiting"
    separator

    exit -1
}

check () 
{
    if [ $? -eq 0 ]; then
        echo "-- Setup $1 Done!"
    else
        quotes "Failed! Cancel the Script"
        abort
    fi
}

submodule () {
    separator
    quotes "Fetch all Submodules Update"

    git submodule update -f -q --init --recursive > /dev/null
    check "Submodules"
}

usage ()
{
    cat << EOF
Usage: $(basename "$0") [options]
Options:
    -m, --model [value]    Specify the Model Code of the Phone (default: d2s)
    -k, --ksu [y/N]        Include KernelSU Next with SuSFS (default: y)
    -h, --help             List all Build Script Command
    -c, --clean [y/N]      Reset all Change to Latest Commit [!! Your Uncommit Change will Lost !!] (default: n)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model|-m)
            MODEL="$2"
            shift 2
            ;;
        --ksu|-k)
            KSU_OPTION="$2"
            shift 2
            ;;
        --ver|-v)
            KERNEL_VERSION="$2"
            shift 2
            ;;
        --rel|-r)
            RELEASE="$2" # Use when Run on GitHub Actions (y: Release - n: CI)
            shift 2
            ;;
        --help|-h)
            usage
            exit 1
            ;;
        --clean|-c)
            CLEAN="$2"
            shift 2
            ;;
        *)\
            usage
            exit 1
            ;;
    esac
done

if [ -z $MODEL ]; then
    MODEL=d2s
fi

KERNEL_DEFCONFIG=oitsminez-"$MODEL"_defconfig
case $MODEL in
beyond0lte)
    SOC=0
    BOARD=SRPRI28A014KU
;;
beyond1lte)
    SOC=0
    BOARD=SRPRI28B014KU
;;
beyond2lte)
    SOC=0
    BOARD=SRPRI17C014KU
;;
beyondx)
    SOC=0
    BOARD=SRPSC04B011KU
;;
d1)
    SOC=5
    BOARD=SRPSD26B007KU
;;
d1xks)
    SOC=5
    BOARD=SRPSD23A002KU
;;
d2s)
    SOC=5
    BOARD=SRPSC14B007KU
;;
d2x)
    SOC=5
    BOARD=SRPSC14C007KU
;;
*)
    usage
    exit
esac

detect_env ()
{
    # Set Build Variable
    separator

    DATE=`date +"%Y%m%d"`
    BUILD_URL="https://raw.githubusercontent.com/oItsMineZKernel/build/refs/heads/exynos9820/"
    REPO_URL="https://raw.githubusercontent.com/ivanmeler/android_kernel_samsung_beyondlte/refs/heads/oneui5_beyond/"
    export KBUILD_BUILD_USER=oItsMineZ
    export KBUILD_BUILD_HOST=Kernel

    if [[ "$SOC" == "5" ]]; then
        DEVICE=Note10
    else
        DEVICE=S10
    fi

    if [ ! -z $RELEASE ]; then
        quotes "Running on GitHub Actions"
        echo BUILD_DEVICE=$DEVICE >> $GITHUB_ENV
    else
        quotes "Running on Local Machine"
        LOCAL=y
    fi

    if [ -z $KERNEL_VERSION ]; then
        KERNEL_VERSION=Unofficial
    fi

    if [ -z $KSU ]; then
        KSU=y
    fi

    if [ -z $CLEAN ]; then
        CLEAN=n
    fi

    separator

    if test -d "build/AIK"; then
        quotes "Android Image Kitchen Directory Found!"
    else
        quotes "Add Android Image Kitchen as Submodule"
        git submodule add -f -q https://github.com/oItsMineZKernel/Android-Image-Kitchen build/AIK > /dev/null && chmod +x build/AIK/mk*
        check "Android Image Kitchen Directory"
    fi

    if test -f "build/AIK/ramdisk/dpolicy" && test -f "build/AIK/init"; then
        quotes "Ramdisk Binary Found!"
    else
        if ! test -d "build/AIK/ramdisk"; then
            mkdir -p build/AIK/ramdisk
        fi
        
        if ! test -f "build/AIK/dpolicy"; then
            quotes "Getting Ramdisk dpolicy"
            curl -LSs "${REPO_URL}ramdisk/ramdisk/dpolicy" -o build/AIK/ramdisk/dpolicy
        fi

        if ! test -f "build/AIK/init"; then
            quotes "Getting Ramdisk init"
            curl -LSs "${REPO_URL}ramdisk/ramdisk/init" -o build/AIK/ramdisk/init && chmod +x build/AIK/ramdisk/i*
        fi

        check "Ramdisk Binary"
    fi

    if ! test -f "build/AIK/fstab.exynos982$SOC"; then
        quotes "Get Fstab for Exynos 982$SOC"
        rm -rf build/AIK/ramdisk/f*
        curl -LSs "${REPO_URL}ramdisk/fstab.exynos982$SOC" -o build/AIK/ramdisk/fstab.exynos982$SOC
        check "Fstab for Exynos 982$SOC"
    fi

    if test -f "build/mkdtimg"; then
        quotes "DTB Build Script Found!"
    else
        quotes "Getting DTB Build Script"
        curl -LSs "${REPO_URL}toolchains/mkdtimg" -o build/mkdtimg && chmod +x build/mk*
        check "DTB Build Script"
    fi

    if test -f "build/dtconfig/exynos982$SOC.cfg" && test -f "build/dtconfig/$MODEL.cfg"; then
        quotes "DTB Config Directory Found!"
    else
        if ! test -d "build/dtconfigs"; then
            mkdir -p build/dtconfigs
        fi

        if ! test -f "build/dtconfig/exynos982$SOC.cfg"; then
            quotes "Getting DTB Config for Exynos 982$SOC"
            curl -LSs "${REPO_URL}toolchains/configs/exynos982$SOC.cfg" -o build/dtconfigs/exynos982$SOC.cfg
        fi

        if ! test -f "build/dtconfig/$MODEL.cfg"; then
            quotes "Getting DTB Config for $DEVICE ($MODEL)"
            curl -LSs "${REPO_URL}toolchains/configs/$MODEL.cfg" -o build/dtconfigs/$MODEL.cfg

            if [[ "$MODEL" == "d2s" ]]; then
                sed -i "s/d2/$MODEL/g" build/dtconfigs/$MODEL.cfg
            elif [[ "$MODEL" == "d1xks" ]]; then
                mv build/dtconfigs/d1x.cfg build/dtconfigs/$MODEL.cfg
            fi
        fi

        check "DTB Config Directory"
    fi

    if ! test -f "build/module-binary"; then
        quotes "Getting Module Binary"
        curl -LSs "https://raw.githubusercontent.com/Zackptg5/MMT-Extended/refs/heads/master/META-INF/com/google/android/update-binary" -o build/module-binary
        check "Module Binary"
    fi

    quotes "Getting Module Props"
    curl -LOSs "${BUILD_URL}module.prop" && curl -LOSs "${BUILD_URL}system.prop" && mv *.p* build
    check "Module Props"

    if ! test -f "build/update-binary"; then
        quotes "Getting Kernel Zip Binary"
        curl -LOSs "${REPO_URL}toolchains/update-binary"
        check "Kernel Zip Binary"
    fi

    quotes "Getting Kernel Zip Script"
    curl -LOSs "${BUILD_URL}updater-script" && mv up* build
    check "Kernel Zip Script"

    check "Build Environment"
}

toolchain ()
{
    separator

    CLANG_VERSION="r416183b1"
    CLANG_INFO="Clang 12.0.7 (Based on $CLANG_VERSION)"

    if test -d "toolchain/clang-$CLANG_VERSION" && test -d "toolchain/aarch64-linux-android-4.9"; then
        quotes "$CLANG_INFO Directory Found!"
    else
        quotes "Add $CLANG_INFO as Submodule"
        git submodule add -f -q https://github.com/ArrowOS-Devices/android_prebuilts_clang_host_linux-x86_clang-r416183b1 toolchain/clang-r416183b1 > /dev/null
        check "clang-$CLANG_VERSION"
    fi

    CLANG=$DIR/toolchain/clang-r416183b1
    PATH=$CLANG/bin:$CLANG/lib:$PATH
    ARGS="
        ARCH=arm64 O=out \
        LLVM=1 LLVM_IAS=1 \
        CC=clang \
        READELF=$CLANG/bin/llvm-readelf \
    "
}

kernelsu ()
{
    separator

    if ! test -f "arch/arm64/configs/ksu-next.config"; then
        quotes "Getting KernelSU Next Defconfig"
        curl -LOSs "https://raw.githubusercontent.com/oItsMineZKernel/build/refs/heads/main/configs/ksu-next.config" && mv ks* arch/arm64/configs
        check "KernelSU Next Defconfig"
    fi

    if test -d "drivers/kernelsu" && grep -rnw 'fs/Makefile' -e 'CONFIG_KSU_SUSFS'; then
        quotes "KernelSU-Next Directory Found! Skipping SuSFS Patch"
    else
        quotes "Add oItsMineZ's KernelSU Next as Submodule"
        separator

        if test -d "KernelSU-Next"; then
            rm -rf Ke*
        fi

        git submodule add -f -q https://github.com/oItsMineZ/KernelSU-Next > /dev/null && curl -LSs "https://raw.githubusercontent.com/oItsMineZ/KernelSU-Next/susfs-v1.5.7/kernel/setup.sh" | bash
        separator
        check "KernelSU Next"

        if ! grep -rnw 'fs/Makefile' -e 'CONFIG_KSU_SUSFS'; then
            separator
            quotes "Patch Kernel Tree with SuSFS"
            separator
            curl -LOSs "https://raw.githubusercontent.com/oItsMineZKernel/build/refs/heads/main/SuSFS.patch" && patch -p1 < SuSFS.patch && rm -rf S*
            separator
            check "SuSFS"
        fi
    fi
}

kernel ()
{
    # Build Kernel Image
    separator
    noquotes "Fetch Kernel Info"
    separator
    noquotes "Device: $DEVICE ("$MODEL")"
    noquotes "SOC: Exynos 982$SOC"
    noquotes "Defconfig: $KERNEL_DEFCONFIG"
    noquotes "Kernel Version: $KERNEL_VERSION"
    noquotes "Build Date: `date +"%Y-%m-%d"`"

    if [ -z $KSU_NEXT ]; then
        noquotes "KernelSU Next with SuSFS: Not Include"
    else
        noquotes "KernelSU Next with SuSFS: Include (Using $KSU_NEXT)"
    fi

    sed -i "s/CONFIG_LOCALVERSION=\"\"/CONFIG_LOCALVERSION=\"-oItsMineZKernel-$KERNEL_VERSION-$DEVICE-$MODEL\"/" $DIR/arch/arm64/configs/$KERNEL_DEFCONFIG
    sed -i "s/CONFIG_LOCALVERSION_AUTO=y/CONFIG_LOCALVERSION_AUTO=n/" $DIR/arch/arm64/configs/$KERNEL_DEFCONFIG

    DEFCONFIG="$KERNEL_DEFCONFIG oitsminez.config $KSU_NEXT"

    separator
    noquotes "Building Kernel Using $KERNEL_DEFCONFIG"
    quotes "Generating Configuration Files"
    separator

    make -j$(nproc --all) $ARGS $DEFCONFIG || abort

    separator
    quotes "Building Kernel"
    separator

    make -j$(nproc --all) $ARGS || abort

    separator
    quotes "Finished Kernel Build!"
    separator

    rm -rf $DIR/build/out/$MODEL
    mkdir -p $DIR/build/out/$MODEL
}

dtb ()
{
    # Build DTB Image
    quotes "Building Device Tree Blob Image for Exynos 982$SOC"
    separator

    $DIR/build/mkdtimg cfg_create $DIR/build/out/$MODEL/dtb_exynos982$SOC.img $DIR/build/dtconfigs/exynos982$SOC.cfg -d $DIR/out/arch/arm64/boot/dts/exynos

    # Build DTBO Image
    separator
    quotes "Building Device Tree Blob Image for $DEVICE ($MODEL)"
    separator

    $DIR/build/mkdtimg cfg_create $DIR/build/out/$MODEL/dtbo_$MODEL.img $DIR/build/dtconfigs/$MODEL.cfg -d $DIR/out/arch/arm64/boot/dts/samsung
}

ramdisk ()
{
    # Build Ramdisk
    separator
    quotes "Building Ramdisk"
    separator

    rm -rf $DIR/build/AIK/s*
    mkdir -p $DIR/build/AIK/split_img
    cp $DIR/out/arch/arm64/boot/Image $DIR/build/AIK/split_img/boot.img-kernel
    echo -e "0x10000000" > build/AIK/split_img/boot.img-base
    echo -e $BOARD > build/AIK/split_img/boot.img-board
    echo -e "loop.max_part=7" > build/AIK/split_img/boot.img-cmdline
    echo -e "sha1" > build/AIK/split_img/boot.img-hashtype
    echo -e "1" > build/AIK/split_img/boot.img-header_version
    echo -e "AOSP" > build/AIK/split_img/boot.img-imgtype
    echo -e "0x00008000" > build/AIK/split_img/boot.img-kernel_offset
    echo -e "45285376" > build/AIK/split_img/boot.img-origsize
    echo -e "2023-04" > build/AIK/split_img/boot.img-os_patch_level
    echo -e "12.0.0" > build/AIK/split_img/boot.img-os_version
    echo -e "2048" > build/AIK/split_img/boot.img-pagesize
    echo -e "0x01000000" > build/AIK/split_img/boot.img-ramdisk_offset
    echo -e "gzip" > build/AIK/split_img/boot.img-ramdiskcomp
    echo -e "0xf0000000" > build/AIK/split_img/boot.img-second_offset
    echo -e "0x00000100" > build/AIK/split_img/boot.img-tags_offset

    # Create Boot Image
    quotes "Calling Android Image Kitchen"

    mkdir -p $DIR/build/AIK/ramdisk/debug_ramdisk
    mkdir -p $DIR/build/AIK/ramdisk/dev
    mkdir -p $DIR/build/AIK/ramdisk/mnt
    mkdir -p $DIR/build/AIK/ramdisk/proc
    mkdir -p $DIR/build/AIK/ramdisk/sys

    cd $DIR/build/AIK && ./mkimg
}

build_zip ()
{
    # Build Zip
    separator
    quotes "Building Zip"
    if [[ "$LOCAL" == "y" ]] || [[ "$RELEASE" == "y" ]]; then
        separator
    fi

    rm -rf $DIR/build/out/$MODEL/zip
    mkdir -p $DIR/build/export
    mkdir -p $DIR/build/out/$MODEL/zip/module/common/
    mkdir -p $DIR/build/out/$MODEL/zip/module/META-INF/com/google/android
    mkdir -p $DIR/build/out/$MODEL/zip/META-INF/com/google/android
    mv $DIR/build/AIK/image-new.img $DIR/build/out/$MODEL/boot-patched.img

    cp $DIR/build/out/$MODEL/boot-patched.img $DIR/build/out/$MODEL/zip/boot.img
    cp $DIR/build/out/$MODEL/dtb_exynos982$SOC.img $DIR/build/out/$MODEL/zip/dtb.img
    cp $DIR/build/out/$MODEL/dtbo_$MODEL.img $DIR/build/out/$MODEL/zip/dtbo.img
    cp $DIR/build/update-binary $DIR/build/out/$MODEL/zip/META-INF/com/google/android/
    cp $DIR/build/updater-script $DIR/build/out/$MODEL/zip/META-INF/com/google/android/

    cp $DIR/build/module.prop $DIR/build/out/$MODEL/zip/module/
    cp $DIR/build/system.prop $DIR/build/out/$MODEL/zip/module/common/
    cp $DIR/build/module-binary $DIR/build/out/$MODEL/zip/module/META-INF/com/google/android/update-binary
    echo -e "#MAGISK" > $DIR/build/out/$MODEL/zip/module/META-INF/com/google/android/updater-script

    cd $DIR/build/out/$MODEL/zip/module
    zip -r ../module.zip .
    rm -rf $DIR/build/out/$MODEL/zip/module

    sed -i "s/ui_print(\" Kernel Version: \");/ui_print(\" Kernel Version: $KERNEL_VERSION\");/" $DIR/build/out/$MODEL/zip/META-INF/com/google/android/updater-script
    sed -i "s/ui_print(\" Kernel Device: \");/ui_print(\" Kernel Device: $DEVICE ($MODEL)\");/" $DIR/build/out/$MODEL/zip/META-INF/com/google/android/updater-script
    sed -i "s/ui_print(\" Kernel Toolchain: \");/ui_print(\" Kernel Toolchain: $CLANG_INFO\");/" $DIR/build/out/$MODEL/zip/META-INF/com/google/android/updater-script
    sed -i "s/CONFIG_LOCALVERSION=\"-oItsMineZKernel-$KERNEL_VERSION-"$DEVICE"-$MODEL\"/CONFIG_LOCALVERSION=\"-oItsMineZKernel-$KERNEL_VERSION-"$DATE"-"$DEVICE"-$MODEL\"/" $DIR/arch/arm64/configs/$KERNEL_DEFCONFIG

    NAME=$(grep -o 'CONFIG_LOCALVERSION="[^"]*"' $DIR/arch/arm64/configs/$KERNEL_DEFCONFIG | cut -d '"' -f 2)
    NAME=${NAME:1}.zip

    if [[ "$LOCAL" == "y" ]] || [[ "$RELEASE" == "y" ]]; then
        cd $DIR/build/out/$MODEL/zip
        zip -r ../"$NAME" .
        rm -rf $DIR/build/out/$MODEL/zip
        mv $DIR/build/out/$MODEL/"$NAME" $DIR/build/export/"$NAME"
        cd $DIR/build/export
    fi
}

# Main Function
rm -rf ./build.log
(
    START=`date +%s`
    DIR=$(pwd)

    separator
    quotes "Preparing Build Environment"

    detect_env
    toolchain

    if [[ "$LOCAL" == "y" ]]; then
        submodule
    fi

    if [[ "$KSU" == "y" ]]; then
        KSU_NEXT=ksu-next.config
        kernelsu
    fi

    kernel
    dtb
    ramdisk
    build_zip

    if [[ "$LOCAL" == "y" ]]; then
        clean
        separator
    fi

    END=`date +%s`

    let "ELAPSED=$END-$START"

    quotes "Total Compile Time was $(($ELAPSED / 60)) Minutes and $(($ELAPSED % 60)) Seconds"
    separator
) 2>&1	| tee -a ./build.log
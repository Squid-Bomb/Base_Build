#!/bin/bash

# ==============================================================================
# Universal ISO Auto-Builder (GUI / Headless Modes)
# Usage: ./build-iso.sh [--gui | --headless]
# ==============================================================================

ORIGINAL_ISO="RHEL_10.1.iso"
KICKSTART_FILE="ks.cfg"
NEW_ISO="rhel-10-lab-server-auto.iso"
VOL_LABEL="RHEL-10-AUTO"
OUTPUT_DIR=$(pwd)
WORKING_DIR="/tmp/rhel-iso-build"
MOUNT_DIR="/mnt/rhel_iso"

MODE="gui"
if [[ "$1" == "--headless" ]]; then
    MODE="headless"
    echo "⚙️  Build Mode: HEADLESS (Serial Console)"
else
    echo "⚙️  Build Mode: GUI (Graphical Installer)"
fi

if [[ $EUID -ne 0 ]]; then
   echo "❌ Error: This script must be run as root or with sudo."
   exit 1
fi

echo "📦 Checking and installing prerequisites..."
if command -v dnf &> /dev/null; then
    dnf install -y xorriso rsync isomd5sum
elif command -v apt-get &> /dev/null; then
    apt-get update && apt-get install -y xorriso rsync isomd5sum
else
    echo "❌ Error: Neither dnf nor apt-get found."
    exit 1
fi

rm -rf "$WORKING_DIR"
mkdir -p "$WORKING_DIR"
mkdir -p "$MOUNT_DIR"

echo "💿 Mounting and extracting original ISO..."
if ! mount -o loop,ro "$ORIGINAL_ISO" "$MOUNT_DIR"; then
    echo "❌ Error: Failed to mount $ORIGINAL_ISO."
    exit 1
fi
rsync -a "$MOUNT_DIR/" "$WORKING_DIR/"
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo "📄 Injecting kickstart file..."
if [[ ! -f "$KICKSTART_FILE" ]]; then
    echo "❌ Error: $KICKSTART_FILE not found."
    exit 1
fi
cp "$KICKSTART_FILE" "$WORKING_DIR/ks.cfg"

echo "🔧 Patching Boot Menus..."

if [[ "$MODE" == "headless" ]]; then
    BOOT_APPEND="inst.ks=hd:LABEL=$VOL_LABEL:/ks.cfg console=ttyS0,115200 inst.text"
else
    BOOT_APPEND="inst.ks=hd:LABEL=$VOL_LABEL:/ks.cfg"
fi

# Patch Legacy BIOS (ISOLINUX)
if [ -f "$WORKING_DIR/isolinux/isolinux.cfg" ]; then
    sed -E -i "s|inst\.stage2=[^ ]+|inst.stage2=hd:LABEL=$VOL_LABEL|g" "$WORKING_DIR/isolinux/isolinux.cfg"
    sed -i "s|inst.stage2=hd:LABEL=$VOL_LABEL|inst.stage2=hd:LABEL=$VOL_LABEL $BOOT_APPEND|g" "$WORKING_DIR/isolinux/isolinux.cfg"
    sed -i 's/timeout 600/timeout 10/' "$WORKING_DIR/isolinux/isolinux.cfg"
    sed -i '/menu default/d' "$WORKING_DIR/isolinux/isolinux.cfg"
    sed -i '/label linux/a \  menu default' "$WORKING_DIR/isolinux/isolinux.cfg"
fi

# Patch UEFI (GRUB)
if [ -f "$WORKING_DIR/EFI/BOOT/grub.cfg" ]; then
    sed -E -i "s|inst\.stage2=[^ ]+|inst.stage2=hd:LABEL=$VOL_LABEL|g" "$WORKING_DIR/EFI/BOOT/grub.cfg"
    sed -i "s|inst.stage2=hd:LABEL=$VOL_LABEL|inst.stage2=hd:LABEL=$VOL_LABEL $BOOT_APPEND|g" "$WORKING_DIR/EFI/BOOT/grub.cfg"
    sed -i 's/set timeout=60/set timeout=10/' "$WORKING_DIR/EFI/BOOT/grub.cfg"
    sed -i 's/set default="1"/set default="0"/' "$WORKING_DIR/EFI/BOOT/grub.cfg"
    sed -i 's/set default=1/set default=0/' "$WORKING_DIR/EFI/BOOT/grub.cfg"
fi

echo "🏗️ Rebuilding the Hybrid ISO..."
cd "$WORKING_DIR" || exit

XORRISO_ARGS=(-as mkisofs -o "$OUTPUT_DIR/$NEW_ISO" -V "$VOL_LABEL" -J -R)
if [ -f "isolinux/isolinux.bin" ]; then
    XORRISO_ARGS+=(-b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table)
fi
if [ -f "images/efiboot.img" ]; then
    if [ -f "isolinux/isolinux.bin" ]; then
        XORRISO_ARGS+=(-eltorito-alt-boot)
    fi
    XORRISO_ARGS+=(-e images/efiboot.img -no-emul-boot -isohybrid-gpt-basdat)
fi

xorriso "${XORRISO_ARGS[@]}" .

cd "$OUTPUT_DIR" || exit
echo "🔒 Implanting MD5 checksum..."
implantisomd5 "$NEW_ISO"

echo "🧹 Cleaning up..."
rm -rf "$WORKING_DIR"
echo "✅ Success! ISO is ready: $NEW_ISO"

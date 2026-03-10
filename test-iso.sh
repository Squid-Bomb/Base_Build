#!/bin/bash

# ==============================================================================
# Universal KVM Test Script (GUI / Headless Modes)
# Usage: ./test-iso.sh [--gui | --headless]
# ==============================================================================

ISO_FILE="rhel-10-lab-server-auto.iso"
DISK_IMG="rhel10-test-disk.qcow2"
DISK_SIZE="40G"
RAM="4096"
CPUS="4"

if [[ "$1" == "--headless" ]]; then
    DISPLAY_ARGS="-nographic"
    echo "⚙️  Test Mode: HEADLESS (Press Ctrl+A, then X to kill)"
else
    DISPLAY_ARGS="-vga virtio"
    echo "⚙️  Test Mode: GUI (Close window to kill)"
fi

echo "🚀 Starting Test Environment..."

echo "📦 Checking virtualization prerequisites..."
if ! command -v qemu-kvm &> /dev/null && ! command -v qemu-system-x86_64 &> /dev/null; then
    if command -v dnf &> /dev/null; then
        sudo dnf install -y qemu-kvm qemu-img edk2-ovmf
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y qemu-kvm qemu-utils ovmf
    else
        echo "❌ Error: Package manager not supported. Install QEMU manually."
        exit 1
    fi
fi

if [[ ! -f "/usr/share/edk2/ovmf/OVMF_CODE.fd" ]] && [[ ! -f "/usr/share/OVMF/OVMF_CODE.fd" ]]; then
    if command -v dnf &> /dev/null; then
        sudo dnf install -y edk2-ovmf
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y ovmf
    fi
fi

QEMU_CMD="qemu-kvm"
if ! command -v qemu-kvm &> /dev/null; then
    QEMU_CMD="qemu-system-x86_64 -enable-kvm"
fi

if [ -f "/usr/share/edk2/ovmf/OVMF_CODE.fd" ]; then
    OVMF_FW="/usr/share/edk2/ovmf/OVMF_CODE.fd"
elif [ -f "/usr/share/OVMF/OVMF_CODE.fd" ]; then
    OVMF_FW="/usr/share/OVMF/OVMF_CODE.fd"
else
    echo "❌ Error: UEFI firmware (OVMF) not found."
    exit 1
fi

if [[ ! -f "$ISO_FILE" ]]; then
    echo "❌ Error: Cannot find ISO file '$ISO_FILE'."
    exit 1
fi

echo "💾 Creating a temporary $DISK_SIZE virtual NVMe disk ($DISK_IMG)..."
qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"

sleep 2

$QEMU_CMD \
  -cpu host \
  -m $RAM \
  -smp $CPUS \
  -bios "$OVMF_FW" \
  -cdrom "$ISO_FILE" \
  -drive file="$DISK_IMG",format=qcow2,if=none,id=NVME1 \
  -device nvme,drive=NVME1,serial=ms01-pipeline \
  -boot d \
  $DISPLAY_ARGS \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0

echo -e "\n🛑 VM shutdown detected."
echo "🧹 Deleting the temporary virtual disk ($DISK_IMG)..."
rm -f "$DISK_IMG"
echo "✅ Test environment successfully cleared."

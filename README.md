RHEL 10 Automated Lab Builder

This repository provides a complete toolkit for building and testing a fully automated Red Hat Enterprise Linux (RHEL) 10 installation ISO. It uses a dynamic Kickstart configuration to handle partitioning and system setup without manual intervention.
🌟 Features

    Automated ISO Injection: Extracts an original RHEL ISO, injects a Kickstart file, and rebuilds the bootable image.

    Dynamic Storage Logic: Includes a %pre script that calculates optimal swap size based on RAM and identifies the best target drive for installation.

    Hybrid Boot Support: Patches both BIOS (ISOLINUX) and UEFI (GRUB) bootloaders for automated execution.

    Dual Mode Support: Allows building and testing in either Graphical (GUI) or Serial Console (Headless) modes.

    Integrated Testing: A dedicated script to launch the ISO in a QEMU/KVM virtual machine with UEFI and NVMe emulation.

🛠️ Prerequisites

    Host OS: A Linux distribution (RHEL, Fedora, or Ubuntu/Debian preferred).

    Source Media: An original RHEL ISO named RHEL_10.1.iso located in the project root.

    Permissions: Root or sudo privileges are required for mounting ISOs and package installation.

    Dependencies: The scripts will automatically attempt to install xorriso, rsync, isomd5sum, and qemu-kvm if they are missing.

📂 File Structure
File	Purpose
build-iso.sh	Orchestrates the extraction, patching, and rebuilding of the RHEL ISO.
test-iso.sh	Launches a temporary QEMU VM to test the automated installation.
ks.cfg	The Kickstart configuration defining system users, packages, and storage.
🚀 Usage
1. Build the Automated ISO

Run the build script to generate the unattended installer. You can choose between a standard GUI installer or a serial-based headless build.
Bash

# For a standard graphical build
sudo ./build-iso.sh

# For a headless build (Serial Console)
sudo ./build-iso.sh --headless

The output file will be rhel-10-lab-server-auto.iso.
2. Test the Installation

Verify the build using the provided QEMU/KVM wrapper. This script creates a temporary 40GB virtual NVMe disk for the test.
Bash

# Test in a GUI window
./test-iso.sh

# Test in headless mode (Press Ctrl+A, then X to exit)
./test-iso.sh --headless

⚙️ Configuration Details
Default User & Security

    Root Account: Locked by default.

    Admin User: lab_admin.

    Password: redhat.

    Privileges: The lab_admin user has passwordless sudo access.

    Security: SELinux is set to enforcing and the firewall is enabled with SSH access allowed.

Storage Layout

The installer dynamically creates the following LVM structure on the smallest available non-removable disk:

    /boot/efi (200MB).

    /boot (1024MB, XFS).

    LVM Volume Group (os_disk):

        swap: Calculated based on RAM (minimum 4GB).

        /: 30% of remaining space.

        /home: 15% of remaining space.

        /var, /tmp, /var/log, /var/log/audit: Dedicated partitions for performance and security.

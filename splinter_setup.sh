#!/bin/bash

# Variables
HOSTNAME=$(hostname -f | cut -d"." -f1)
HW_TYPE=$(geni-get manifest | grep $HOSTNAME | grep -oP 'hardware_type="\K[^"]*')
OS_VER="ubuntu`lsb_release -r | cut -d":" -f2 | xargs`"
NUM_CPUS=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
MLNX_OFED="MLNX_OFED_LINUX-4.1-1.0.2.0-$OS_VER-x86_64"

# Test if startup service has run before.
if [ -f /local/startup_service_done ]; then
    # Configurations that need to be (re)done after each reboot

    # TODO: Bind NIC to dpdk.

    exit 0
fi

# Install common utilities
apt-get update
apt-get --assume-yes install mosh vim tmux pdsh tree axel

# Install NetBricks dependencies.
apt-get --assume-yes install libgnutls30 libgnutls-openssl-dev \
        libcurl4-gnutls-dev libnuma-dev libpcap-dev clang numactl

# Change user login shell to Bash
for user in `ls /users`; do
    chsh -s `which bash` $user
done

# Fix "rcmd: socket: Permission denied" when using pdsh
echo ssh > /etc/pdsh/rcmd_default

# Enable hugepage support: http://dpdk.org/doc/guides/linux_gsg/sys_reqs.html
# The changes will take effects after reboot.
# Reserve 1GB hugepages via kernel boot parameters
kernel_boot_params="default_hugepagesz=1G hugepagesz=1G hugepages=16"

# Disable intel_idle driver to gain control over C-states (this driver will
# most ignore any other BIOS setting and kernel parameters). Then limit
# available C-states to C1 by "idle=halt".
kernel_boot_params+=" intel_idle.max_cstate=0 idle=halt"
# Or more aggressively, keep processors in C0 even when they are idle.
#kernel_boot_params+=" idle=poll"

# Update GRUB with our kernel boot parameters
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_boot_params /" /etc/default/grub
update-grub

# Download Mellanox OFED package
if [ ! -z "$MLNX_OFED" ]; then
    axel -n 8 -q http://content.mellanox.com/ofed/MLNX_OFED-4.1-1.0.2.0/$MLNX_OFED.tgz
    tar xzf $MLNX_OFED.tgz
fi

if [ ! -z "$MLNX_OFED" ]; then
    # Install Mellanox OFED (need reboot to work properly). Note: attempting to build
    # MLNX DPDK before installing MLNX OFED may result in compile-time errors.
    $MLNX_OFED/mlnxofedinstall --force
fi

# Mark the startup service has finished
> /local/startup_service_done

# Reboot to let the configuration take effects
reboot

#!/usr/bin/env bash
set -euo pipefail

export LIBVIRT_DEFAULT_URI="qemu:///system"

# -------- Configuration --------

VM_PREFIX="auto-vm"
ISO_PATH="/var/lib/libvirt/images/ubuntu-24.04.iso"
IMAGE_DIR="/var/lib/libvirt/images"

DEFAULT_DISK_SIZE="20G"

# User input
VM_COUNT="${1:-1}"
MAX_PARALLEL="${2:-2}"

# -------- Host resources --------

HOST_CPUS=$(nproc)

HOST_MEM_MB=$(
    awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
)

# Keep some resources for host
RESERVED_MEM_MB=4096
AVAILABLE_MEM_MB=$((HOST_MEM_MB - RESERVED_MEM_MB))

# Allocate
VM_RAM_MB=$((AVAILABLE_MEM_MB / VM_COUNT))

# Clamp RAM
if (( VM_RAM_MB > 8192 )); then
    VM_RAM_MB=8192
fi

if (( VM_RAM_MB < 1024 )); then
    echo "Not enough RAM available"
    exit 1
fi


VM_VCPUS=$((HOST_CPUS / VM_COUNT))

# Clamp CPU
if (( VM_VCPUS > 4 )); then
    VM_VCPUS=4
fi

if (( VM_VCPUS < 1 )); then
    VM_VCPUS=1
fi


echo "Planning deployment:"
echo "VMs:        $VM_COUNT"
echo "Parallel:   $MAX_PARALLEL"
echo "RAM/VM:     ${VM_RAM_MB}MB"
echo "CPU/VM:     ${VM_VCPUS}"
echo


# -------- VM creation --------

create_vm() {
    local INDEX=$1
    local NAME="${VM_PREFIX}-${INDEX}"
    local DISK="${IMAGE_DIR}/${NAME}.qcow2"

    echo "Creating $NAME"

    if virsh dominfo "$NAME" >/dev/null 2>&1; then
        echo "$NAME already exists, skipping"
        return
    fi

    qemu-img create \
        -f qcow2 \
        "$DISK" \
        "$DEFAULT_DISK_SIZE"


    virt-install \
        --connect qemu:///system \
        --name "$NAME" \
        --ram "$VM_RAM_MB" \
        --vcpus "$VM_VCPUS" \
        --disk path="$DISK",format=qcow2 \
        --cdrom "$ISO_PATH" \
        --network network=default \
        --graphics vnc \
        --noautoconsole

    echo "$NAME created"
}


export -f create_vm
export VM_PREFIX IMAGE_DIR DEFAULT_DISK_SIZE ISO_PATH
export VM_RAM_MB VM_VCPUS


# -------- Parallel execution --------

running=0

for i in $(seq 1 "$VM_COUNT"); do

    create_vm "$i" &

    ((running++))

    if (( running >= MAX_PARALLEL )); then
        wait
        running=0
    fi

done

wait

echo "All VMs deployed."

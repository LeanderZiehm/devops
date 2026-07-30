



run:
```
curl -L -C - -O https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
```

then install qemu:

```
sudo dnf install qemu
```

generate private key
```
ssh-keygen -t ed25519 -f ~/.ssh/debian13_vm1
cat ~/.ssh/debian13_vm1.pub
```

then install sudo dnf install cloud-utils

```
sudo dnf install cloud-utils
```

```
cloud-localds seed.iso user-data
```

```
qemu-system-x86_64 -enable-kvm -m 512M -smp 1 -drive file=debian-13-generic-amd64.qcow2,if=virtio,format=qcow2 -drive file=seed.iso,if=virtio,format=raw -nic user,model=virtio,hostfwd=tcp::2222-:22 -nographic
```
<!-- qemu-system-x86_64 -enable-kvm -m 512M -smp 1 -drive file=debian-13-generic-amd64.qcow2,if=virtio,format=qcow2 -nic user,model=virtio -nographic -->

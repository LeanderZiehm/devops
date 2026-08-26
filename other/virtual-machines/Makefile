run:
	cloud-localds seed.iso user-data1
	qemu-system-x86_64 -enable-kvm -m 512M -smp 1 -drive file=debian-13-generic-amd64.qcow2,if=virtio,format=qcow2 -drive file=seed.iso,if=virtio,format=raw -nic user,model=virtio,hostfwd=tcp::2222-:22 -nographic
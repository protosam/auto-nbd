# Network Block Device (nbd)
This container was built to create a QCOW2 image and connect it to a `/dev/nbd*` device using `qemu-nbd`. It is mostly just a useful hack for getting storage solution working in KinD on non-linux machines like in this [tutorial](https://github.com/protosam/tutorial-rook-ceph-in-kind).

## Usage
Create a docker volume to persist your qemu images.
```
docker volume create qemu-images
```

Start the container so that it will restart unless manually stopped.
```
docker run -d --restart unless-stopped --pid=host --privileged \
    -v "qemu-images:/data/qemu-images" -v '/dev:/dev' \
    -e QCOW2_IMG_PATH=/data/qemu-images/developer.qcow2 \
    -e NBD_DEV_PATH=/dev/nbd0 \
    -e QCOW2_IMG_SIZE=60G \
    -e VG_NAME=myvolgrp \
    --name auto-nbd \
    ghcr.io/protosam/auto-nbd
```

Accessing the container can be useful if you want to view storage details.
```
# docker exec -it auto-nbd bash
root@9d7c9984a5e9:/# vgs
  VG       #PV #LV #SN Attr   VSize   VFree
  myvolgrp   1   0   0 wz--n- <60.00g <60.00g
root@9d7c9984a5e9:/# lsns -t pid
        NS TYPE NPROCS   PID USER COMMAND
4026531836 pid     148     1 root /sbin/init
4026532226 pid       1   979 root /allowlist
4026532395 pid       1  1025 root /artifactory-agent --docker-desktop-mode
4026532397 pid       1  1229 root dhcpcd: [master] [ip4]
4026532400 pid       1  1187 root /devenv-server -socket /run/guest-services/devenv-volumes.sock
4026532403 pid       1  1331 root /usr/bin/dns-forwarder -dns.port 53 -conf /etc/coredns/Corefile
4026532406 pid       1  1447 root /http-proxy
4026532408 pid       1  1506 root /usr/bin/kmsg
4026532526 pid       2  1640 root /start 30
4026532530 pid       1  1801 root /usr/bin/trim-after-delete -- /sbin/fstrim /var/lib/docker
4026532532 pid       1  1852 root /usr/bin/volume-contents
4026532534 pid       1  1898 root /usr/bin/vpnkit-forwarder -data-connect /run/host-services/vpnkit-data.sock -data-listen /run/guest-services/wsl2-expose-ports.sock
4026532666 pid       1 25935 root bash
```

## Volume Management
Volumes can be managed inside the container. Here is how to get in and remove a volume.
```
% docker exec -it auto-nbd bash
root@b843c9fe6d5d:/# vgs
  VG       #PV #LV #SN Attr   VSize   VFree
  myvolgrp   1  10   0 wz--n- <60.00g <50.00g

root@b843c9fe6d5d:/# lvs --noheading
  pvc-4ba801bf-b7f6-4d85-ba69-4a51b52ac76a myvolgrp -wi------- 1.00g
  pvc-5447de1a-b983-4de1-8dfd-ec6f77e52419 myvolgrp -wi------- 1.00g
  pvc-68f79916-1f64-46f2-babe-2aaf74f0ad2b myvolgrp -wi------- 1.00g
  pvc-6ff7eb10-af74-49b5-9927-f06cce4279a1 myvolgrp -wi------- 1.00g
  pvc-a8a5c7f4-5c0a-4c73-bd21-16b3dc50b27b myvolgrp -wi------- 1.00g
  pvc-a9af3318-2170-4099-ae46-94fc415199c4 myvolgrp -wi------- 1.00g
  pvc-fd34d484-6624-457f-b6aa-e5c65db2c27d myvolgrp -wi------- 1.00g


root@b843c9fe6d5d:/# lvremove /dev/myvolgrp/pvc-4ba801bf-b7f6-4d85-ba69-4a51b52ac76a
  Logical volume "pvc-4ba801bf-b7f6-4d85-ba69-4a51b52ac76a" successfully removed
```

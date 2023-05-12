#!/bin/bash
function usage(){
cat <<EOF
Required environment variables:
    QCOW2_IMG_PATH     Path to QCOW2 file to connect to NBD device.
    NBD_DEV_PATH       NBD device to use.
    QCOW2_IMG_SIZE     Size to initially make QCOW2 file.
    VG_NAME            Name of LVM volume group to place block device in.

Example invocation:
    docker volume create qemu-images
    docker run -d --restart unless-stopped --pid=host --privileged \\
        -v "qemu-images:/data/qemu-images" \\
        -v "/dev:/dev" \\
        -e QCOW2_IMG_PATH=/data/qemu-images/developer.qcow2 \\
        -e NBD_DEV_PATH=/dev/nbd0 \\
        -e QCOW2_IMG_SIZE=60G \\
        -e VG_NAME=myvolgrp \\
        --name auto-nbd \\
        ghcr.io/protosam/auto-nbd
EOF
exit 1
}

[ -z "${QCOW2_IMG_PATH}" ] && usage
[ -z "${NBD_DEV_PATH}" ] && usage
[ -z "${QCOW2_IMG_SIZE}" ] && usage
[ -z "${VG_NAME}" ] && usage

# create qcow file if does not exist
[ -f "${QCOW2_IMG_PATH}" ] || qemu-img create -f qcow2 "${QCOW2_IMG_PATH}" "${QCOW2_IMG_SIZE}"

PID_FILE="${QCOW2_IMG_PATH}.pid"

NBD_DEV_SIZE_PATH="/sys/class/block/${NBD_DEV_PATH#/dev/}/size"

# this detects and cleans up devices held open due to LVM
MAJMIN=$(lsblk "${NBD_DEV_PATH}" -no MAJ:MIN | tr -d "[:blank:]")
if [ ! -z "${MAJMIN}" ] && [ ! -d "/proc/$(cat "${PID_FILE}")" ]; then
    for MAPPED_DEV_NAME in $(dmsetup table | grep "${MAJMIN}" | cut -d: -f1); do
        echo "Performing cleanup for disconnected nbd: ${MAPPED_DEV_NAME}/${MAJMIN}"
        dmsetup remove "${MAPPED_DEV_NAME}" || exit 1
    done

    for i in {1..60}; do
        if [ "$(cat "${NBD_DEV_SIZE_PATH}")" -ne "0" ]; then
            echo "Waiting for device ${NBD_DEV_PATH} to be released."
            sleep 5
        fi
    done

    if [ "$(cat "${NBD_DEV_SIZE_PATH}")" -ne "0" ]; then
        echo "ERROR: Timed out waiting for device ${NBD_DEV_PATH} to be released."
        exit 1
    fi

    echo "Cleanup completed."
fi


# ensure nbd device is not in use
if [ "$(cat "${NBD_DEV_SIZE_PATH}")" -ne "0" ]; then
    echo "ERROR: ${NBD_DEV_PATH} already in use."
    exit 1
fi


# connect cowfile to nbd dev
qemu-nbd --connect "${NBD_DEV_PATH}" "${QCOW2_IMG_PATH}" --cache=directsync --pid-file "${PID_FILE}"

# create physical volume if it does not already exist
pvs "${NBD_DEV_PATH}" || pvcreate "${NBD_DEV_PATH}"

# check if volume group exists
if vgs "${VG_NAME}"; then
    # the volume group exists, check if physical volume is already in this volume group
    if ! pvs "${NBD_DEV_PATH}" | grep -q "${VG_NAME}"; then
        # extend the volume group with new physical volume
        vgextend "${VG_NAME}" "${NBD_DEV_PATH}" || exit 1
    fi
else
    # craete new volume group with this physical volume or fail
    vgcreate "${VG_NAME}" "${NBD_DEV_PATH}" || exit 1
fi

NBD_PID=$(cat "${PID_FILE}")

echo "Network block device attached successfully."
while [ -d "/proc/${NBD_PID}" ]; do sleep 5; done
echo "Failed to find /proc/${NBD_PID}"
exit 1

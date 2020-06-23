#!/bin/sh
#
# Archive home directory and remove domain
#
set -e

error () {
    echo "$@" 1>&2
    exit 1
}

if [ "$(id -u)" != 0 ]; then
    error "$(whoami): Permission denied"
fi

# Check dependencies
for dep in virsh cryptsetup qemu-nbd cryptsetup vgscan vgchange jq xmllint shuf; do
    if ! type $dep >/dev/null; then
        error "$dep: Not found"
    fi
done

if [ $# -ne 2 ]; then
    error "Usage: $(basename $0) <domain>"
fi

# Check if domain exists
if ! virsh list --all --name | grep "$domain" >/dev/null; then
    error "$domain: Not found"
fi

# Check if domain is active
if virsh list --state-running --name | grep "$domain" >/dev/null; then
    error "$domain: Is active"
else

# Find path to first disk image
disk_image=$(virsh dumpxml "$domain" | xmllint --xpath 'string(//domain/devices/disk[1]/source/@file)' -)

# Determine image format (raw or qcow2)
disk_format=$(qemu-img info $disk_image --output json | jq -r '.format')

# Load nbd module
if ! lsmod | cut -f1 -d' ' | grep nbd; then
    modprobe nbd max_part=8
fi

# Connect /dev/nbd0 to disk image
qemu-nbd -f "$disk_format" -c /dev/nbd0 $disk_image

echo "[*] Opening /dev/nbd0p5"
cryptsetup luksOpen /dev/nbd0p5 tmpvol  # Assuming nbd0p5
vgscan
vgchange -ay $lvm_name
mount /dev/$lvm_name/root /mnt

echo "[*] Creating encrypted archive"
pass_len="$(shuf -i 10-32 -n 1)"
passphrase="$(openssl rand -hex $pass_len)"
echo "[*] Password: $passphrase"
tar zcvf - /mnt/home | openssl aes256 etc..

echo "[*] Removing domain"
. virsh-remove.sh $domain_name

echo "[*] Cleaning up"
umount /mnt
vgchange -an $lvm_name
qemu-nbd --disconnect /dev/bbd0
rmmod nbd


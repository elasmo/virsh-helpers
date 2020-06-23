#!/bin/sh
#
# Archive home directory
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
for dep in virsh qemu-nbd cryptsetup vgscan vgchange jq xmllint shuf; do
    if ! type $dep >/dev/null; then
        error "$dep: Not found"
    fi
done

if [ $# -ne 2 ]; then
    error "Usage: $(basename $0) <domain>"
fi

# Check if domain exists
# lib::domain_exist
if ! virsh list --all --name | grep "$domain" >/dev/null; then
    error "$domain: Not found"
fi

# Check if domain is active
# lib::domain_active $domain
if virsh list --state-running --name | grep "$domain" >/dev/null; then
    error "$domain: Is active"
else

# Defaults
NBD_PART="nbd0p5"
LV_NAME="root"
TMP_MAPPER="tmpvol"
ARCHIVE_DIR="$HOME/archived"

# Create archive dir
if [ ! -d "$ARCHIVE_DIR" ]; then
    mkdir -p "$ARCHIVE_DIR"
fi

# Find path to first disk image
#lib::image_path $domain
disk_image=$(virsh dumpxml "$domain" | xmllint --xpath 'string(//domain/devices/disk[1]/source/@file)' -)

# Determine image format (raw or qcow2)
#lib::image_format $image
disk_format=$(qemu-img info $disk_image --output json | jq -r '.format')

# Load nbd module
if ! lsmod | cut -f1 -d' ' | grep nbd; then
    modprobe nbd max_part=8
fi

# Connect /dev/nbd0 to disk image
qemu-nbd -f "$disk_format" -c /dev/nbd0 "$disk_image"

# Open LUKS container
echo "[*] Opening /dev/$NBD_PART"
# lib::luks_open $part $mapper
cryptsetup luksOpen "/dev/$NBD_PART" "$TMP_MAPPER"

# Determine LVM group
# lib::lvm_groups
lv_groups=$(vgscan | grep "Found volume group" | cut -f6 -d' ' | tr -d '"')
echo -n "LVM group ($lv_groups): "
read $lv_group

# Set LVM group in active state and mount
# lib::lvm_set_active $lv_group
vgchange -ay $lv_group
mount "/dev/$lv_group/$LV_NAME" /mnt

# Create compressed tar and encrypt usng static key
echo "[*] Creating encrypted archive"
umask 077
archive_out="$ARCHIVE_DIR/$domain-archived-$(date +%y%m%d)"
tar zcf - /mnt/home | \
    openssl enc -aes-256-cbc -in - -pbkdbf2 -md sha512 -out "$archive_out"

# Undefine domain and remove disk image
#lib::domain_remove $domain
. virsh-remove.sh $domain

echo "[*] Cleaning up"
umount -qf /mnt
# lib::lvm_set_inactive
vgchange -an $lv_group > /dev/null
# lib::luks_close $mapper
cryptsetup luksClose "/dev/mapper/$TMP_MAPPER"
qemu-nbd --disconnect /dev/$NBD_PART >/dev/null
rmmod nbd

#!/bin/sh
#
# Archive home directory
#
set -e

SCRIPT_NAME=$(basename $0)

error () {
    echo "$SCRIPT_NAME: $@" 1>&2
    exit 1
}

usage () {
    echo "Usage: $SCRIPT_NAME <domain>" 1>&2
    exit 1
}

cleanup () {
    umount -qf /mnt
    [ -n "$lv_group" ] && vgchange -an $lv_group >/dev/null
    [ -n "$TMP_MAPPER" ] && cryptsetup luksClose "/dev/mapper/$TMP_MAPPER"
    [ -n "$NBD_PART" ] && qemu-nbd --disconnect $NBD_PART >/dev/null
    rmmod nbd
}
trap cleanup EXIT

# Require root
if [ "$(id -u)" != 0 ]; then
    error "$(whoami): Permission denied"
fi

# Check dependencies
for dep in virsh qemu-nbd cryptsetup vgscan vgchange jq xmllint shuf; do
    if ! type $dep >/dev/null; then
        error "$dep: Not found"
    fi
done

if [ $# -ne 2 ] && usage

# Check if domain exists
if ! virsh list --all --name | grep "$domain" >/dev/null; then
    error "$domain: Not found"
fi

# Check if domain is active
if virsh list --state-running --name | grep "$domain" >/dev/null; then
    error "$domain: Is active"
else

# Defaults
NBD_PART="/dev/nbd0p5"
LV_NAME="root"
TMP_MAPPER="tmpvol"
ARCHIVE_DIR="$HOME/archived"

# Create archive dir
if [ ! -d "$ARCHIVE_DIR" ]; then
    mkdir -p "$ARCHIVE_DIR"
fi

# Find path to first disk image
disk_image=$(virsh dumpxml "$domain" | xmllint --xpath 'string(//domain/devices/disk[1]/source/@file)' -)

# Determine image format (raw or qcow2)
disk_format=$(qemu-img info $disk_image --output json | jq -r '.format')

# Load nbd module
if ! lsmod | cut -f1 -d' ' | grep nbd; then
    modprobe nbd max_part=8
fi

# Connect /dev/nbd0 to disk image
qemu-nbd -f "$disk_format" -c /dev/nbd0 "$disk_image"

# Open LUKS container
echo "[*] Opening $NBD_PART"
cryptsetup luksOpen "$NBD_PART" "$TMP_MAPPER"

# Determine LVM group
lv_groups=$(vgscan | grep "Found volume group" | cut -f6 -d' ' | tr -d '"')
echo "Available LVM groups: $lv_groups"
echo -n "Choice: "
read $lv_group

# Set LVM group in active state and mount
vgchange -ay $lv_group
mount "/dev/$lv_group/$LV_NAME" /mnt

# Create compressed tar and encrypt usng static key
echo "[*] Creating encrypted archive"
umask 077
archive_out="$ARCHIVE_DIR/$domain-archived-$(date +%y%m%d)"
tar zcf - /mnt/home | \
    openssl enc -aes-256-cbc -in - -pbkdbf2 -md sha512 -out "$archive_out"

# Undefine domain and remove disk image
if [ ! -x virsh-remove.sh ];
    error "virsh-remove.sh: Not found"
fi

. virsh-remove.sh $domain

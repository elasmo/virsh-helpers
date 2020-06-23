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
lib::core::check_dependencies "virsh qemu-nbd cryptsetup vgscan vgchange jq xmllint shuf"

if [ $# -ne 2 ]; then
    error "Usage: $(basename $0) <domain>"
fi

# Check if domain exists
lib::domain::exist "$domain"

# Check if domain is active
lib::domain::is_active "$domain"

# Defaults
NBD_PART="/dev/nbd0p5"
LV_NAME="root"
TMP_MAPPER="tmpvol"
ARCHIVE_DIR="$HOME/archived"

# Create archive dir
mkdir -p "$ARCHIVE_DIT"

# Find path to first disk image
lib::image::path "$domain"

# Determine image format (raw or qcow2)
lib::image::get_format "$image"

# Load nbd module
lib::nbd::init

# Connect /dev/nbd0 to disk image
lib::nbd::connect "$disk_format" "$disk_image"

# Open LUKS container
echo "[*] Opening $NBD_PART"
lib::luks::open "$NBD_PART" "$TMP_MAPPER"

# Determine LVM group
lib::lvm::get_groups
echo -n "LVM group ($lv_groups): "
read $lv_group

# Set LVM group in active state and mount
lib::lvm::set_active $lv_group

mount "/dev/$lv_group/$LV_NAME" /mnt

# Create compressed tar and encrypt usng static key
echo "[*] Creating encrypted archive"
umask 077
archive_out="$ARCHIVE_DIR/$domain-archived-$(date +%y%m%d)"
tar zcf - /mnt/home | \
    openssl enc -aes-256-cbc -in - -pbkdbf2 -md sha512 -out "$archive_out"

# Undefine domain and remove disk image
lib::domain::remove "$domain"

echo "[*] Cleaning up"
umount -qf /mnt
lib::lvm::set_inactive
lib::luks:close "$TMP_MAPPER"
lib::nbd::deinit
lib::nbd::disconnect "$NBD_PART"

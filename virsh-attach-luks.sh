#!/usr/bin/env bash
#
# XXX Work in progress
#
# Attach LUKS container to domain guest
#
# Exposes a device target in guest. Example:
#   host$ virsh-attach-luks.sh guest 2G
#   guest# cryptsetup luksOpen /dev/vdb vol
#   guest#  mount /dev/mapper/vol /mnt
# 
set -e

error () {
    echo "$@" 1>&2
    exit 1
}

usage () {
    echo "Usage: $(basename $0) <domain> <size>" 1>&2
    exit 1
}

[ $# -eq 0 ] && usage

# Check dependencies
for dep in virsh cryptsetup xmllint openssl sudo; do
   if ! type $dep >/dev/null; then
       error "$dep: Not found"
   fi
done

trap error ERR

domain="$1"
size="10G"
vol_dir="$(virsh pool-dumpxml default | xmllint --xpath '//path/text()' -)"
cryptvol_dir="$vol_path/cryptvols"
cryptvol_path="$cryptvol_dir/$domain-$(date +%y%m%d).luks"
cryptvol_name="$(basename $cryptvol_path)"
cryptvol_mapper="$domain-$(date +%y%m%d).mapper"
passphrase="$(openssl rand -hex 32)"

# Check if domain exists
if ! virsh list --all --name | grep "$domain" >/dev/null; then
    error "$domain: Not found"
fi

# Check if cryptvol already exist
[ -f "$cryptvol_path" ] && error "$cryptvol_name: Already exist"

# Find next free device target to use
targets="$(virsh dumpxml $domain | xmllint --xpath '//domain/devices/disk/target[@bus="virtio"]/@dev' -)"

can_use=1
for t in b c d e f; do
    for target in $targets; do
        device="$(echo $target | cut -f2 -d'=' | tr -dc a-z)"

        # Check if disk ident is listed among existent device targets
        [ "$device" = "vd$t" ] && can_use=0
    done

    if [ $can_use -eq 1 ]; then
        vol_target="vd$t"
        break
    fi

    can_use=1
done

# Set volume size if specified
[ ! -z "$2" ] && size="$2"

# Create volume directory
[ ! -d "${vol_root}" ] && mkdir -p "$cryptvol_dir"

echo "[*] Truncating \"$cryptvol_name\" to $size"
truncate -s "$size" "$cryptvol_path"

echo "[*] Initializes a LUKS partition"
echo "$passphrase" | sudo cryptsetup luksFormat "$cryptvol_path"
echo "[*] Passphrase: $passphrase"

echo "[*] Creating ext4 filesystem"
echo "$passphrase" | sudo cryptsetup open "$cryptvol_path" "$cryptvol_mapper"
sudo mkfs.ext4 "/dev/mapper/$cryptvol_mapper" > /dev/null 2>&1
sync
sudo cryptsetup close "$cryptvol_mapper"
unset $passphrase

echo "[*] Attaching $cryptvol_name to $domain"
virsh attach-disk "$domain" "$cryptvol_path" "$vol_target" --cache none > /dev/null

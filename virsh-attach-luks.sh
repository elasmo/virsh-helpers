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

domain_name="$1"
size="10G"
vol_dir="$(virsh pool-dumpxml default | xmllint --xpath '//path/text()' -)"
cryptvol_dir="$vol_path/cryptovols"
cryptvol_name="$cryptvol_dir/$domain_name-$(date +%y%m%d).luks"
cryptvol_mapper="$domain_name-$(date +%y%m%d).mapper"
passphrase="$(openssl rand -hex 32)"

# Check if domain exists
if ! virsh list --all --name | grep "$domain" >/dev/null; then
    error "$domain: Not found"
fi

# Find next free device target to use
targets="$(virsh dumpxml meeting | xmllint --xpath '//domain/devices/disk/target[@bus="virtio"]/@dev' -)"
for t in b c d e f; do
    for target in $targets; do
        target="$(echo $target | cut -f2 -d'=' | tr -dc a-z)"
        if [ "$target" != "vd$t" ]; then
            vol_target="vd$t"
            break 2
        fi
    done
done

# Set volume size if specified
[ ! -z "$2" ] && size="$2"

# Create volume directory
[ ! -d "${vol_root}" ] && mkdir -p "$cryptvol_dir"

echo "[*] Truncating $cryptvol_name to $size"
truncate -s "$size" "$cryptvol_name"

echo "[*] Initializes a LUKS partition"
echo "$passphrase" | sudo cryptsetup luksFormat "$cryptvol_name"
echo "[*] Passphrase: $passphrase"

echo "[*] Creating ext4 filesystem"
echo "$passphrase" | sudo cryptsetup open "$cryptvol_name" "$cryptvol_mapper"
sudo mkfs.ext4 "/dev/mapper/$cryptvol_mapper" > /dev/null 2>&1
sync
sudo cryptsetup close "$cryptvol_mapper"
unset $passphrase

echo "[*] Attaching disk to $domain_name"
virsh attach-disk "$domain_name" "$cryptvol_name" "$vol_target" --cache none > /dev/null

#!/bin/sh
#
# Share filesystem between guests
#
set -e

SCRIPT_NAME=$(basename $0)

error () {
    echo "$@" 1>&2
    exit 1
}

usage () {
    echo "Usage: $SCRIPT_NAME [-f source] [-t dest] [-s size]" 1>&2
    exit 1
}

# Check dependencies
for dep in virsh xmllint truncate mkfs.ext4; do
    if ! type $dep >/dev/null; then
        error "$dep: Not found"
    fi
done

# Parse arguments
[ $# -lt 1 ] && usage

while getopts f:t: opt
do      
    case "$opt" in
        f) src_domain="$OPTARG";;
        t) dst_domain="$OPTARG";;
        s) size="$OPTARG";;
        ?) usage;;
        esac
done

# Defaults
size="100M"

# Create filesystem
tmp_fs=`mktemp --suffix=.img`
truncate -s "$size" "$tmppath"
mkfs.ext4 "$tmp_fs"

# Share between guest and host
if [ -n "$src_domain" ] && [ -z "$dst_domain" ]; then
    echo 
# Share between guest and guest
elif [ -n "$src_domain" ] && [ -n "$dst_domain" ]; then
    echo
# Share between host and guest
elif [ -z "$src_domain" ] && [ -n "$dst_domain" ]; then
    tmp_mnt=`mktemp -p "$HOME" -d --suffix=.mnt`
    sudo mount "$tmp_fs" "$tmp_mnt"
    read
    sudo umount "$tmp_mnt"
    virsh attach-disk "$dst_domain" "$tmp_mnt" vdd --cache none
    read
    virsh detach-disk "$dst_domain" vdd
    rm -vfr "$tmp_mnt" "$tmp_fs"
fi

echo "dummy"

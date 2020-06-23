#!/bin/sh
#
# Undefine and remove domain
#
set -e

error () {
    echo "$@" 1>&2
    exit 1
}

usage () {
    echo "Usage: $(basename $0) <domain>" 1>&2
    exit 1
}

[ $# -ne 1 ] && usage

# Check dependencies
for dep in virsh awk; do
    if ! type virsh awk >/dev/null; then
        error "$dep: Not found"
    fi
done

domain=$1
disk_image=$(virsh domblklist "$domain" | grep "libvirt/images" | awk -v x=2 '{print $x}')

echo "Removing $domain ($disk_image)"
echo "^C to abort"
read

virsh undefine "$domain"
rm -v "$disk_image"

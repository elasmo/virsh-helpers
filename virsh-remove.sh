#!/bin/sh
#
# Undefine and remove domain
#
set -e

error () {
    echo "$@" 1>&2
    exit 1
}

# Check dependencies
for dep in virsh awk; do
    if ! type virsh awk >/dev/null; then
        error "$dep: Not found"
    fi
done

if [ $# -ne 1 ]; then
    error "Usage: $(basename $0) <domain>"
fi

domain=$1
disk_image=$(virsh domblklist "$domain" | grep "libvirt/images" | awk -v x=2 '{print $x}')

printf "Removing $domain ($disk_image)\n^C to abort.\n"
read
virsh undefine "$domain"
rm -v "$disk_image"

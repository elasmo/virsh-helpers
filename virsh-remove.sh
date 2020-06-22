#!/bin/sh
#
# Virsh helper to undefine and remove domain
#
set -e

if ! type virsh >/dev/null; then
    echo "virsh not found"
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) <domain>"
    exit 1
fi

domain=$1
vm_image=$(virsh domblklist "$domain" | grep "libvirt/images" | awk -v x=2 '{print $x}')

printf "Removing $domain ($vm_image)\n^C to abort.\n"
read
virsh undefine "$domain"
rm -v "$vm_image"

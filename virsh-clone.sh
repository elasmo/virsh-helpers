#!/bin/sh
#
# Clone a domain
#
set -e

error () {
    echo "$@" 1>&2
    exit 1
}

# Check dependencies
for dep in virsh virt-clone xmllint; do
    if ! type $dep >/dev/null; then
        error "$dep: Not found"
    fi
done

if [ $# -ne 2 ]; then
    error "Usage: $(basename $0) <source> <dest>"
fi

src_name="$1"
dst_name="$2"
image_path="$(virsh pool-dumpxml default | xmllint --xpath '//path/text()' -)"
src_image="$(virsh domblklist "$src_name" | grep "libvirt/images" | awk -v x=2 '{print $x}')"
dst_image="$image_path/$dst_name.qcow2"

virt-clone -o "$src_name" -n "$dst_name" -f "$dst_image"

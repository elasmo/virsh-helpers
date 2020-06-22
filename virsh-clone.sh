#!/bin/sh
#
# Virsh helper to clone a domain
#
set -e

for dep in virsh virt-clone xmllint; do
   if ! type $dep >/dev/null; then
      echo "Missing: $dep"
      exit 1
   fi
done

if [ $# -ne 2 ]; then
    echo "Usage: $(basename $0) <source> <destination>"
    exit 1
fi

src_name="$1"
dst_name="$2"
src_image="$(virsh domblklist $src_name | grep "libvirt/images" | awk -v x=2 '{print $x}')"
image_path="$(virsh pool-dumpxml default | xmllint --xpath '//path/text()' -)"
dst_image="$image_path/$dst_name.qcow2"

virt-clone -o "$src_name" -n "$dst_name" -f "$dst_image"

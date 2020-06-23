#!/usr/bin/env bash
#
# Create a LUKS encrypted volume and attach it to
# a virsh managed domain
#
# Usage examples:
# host$ attach-luks myvm 5G
# host$ attach-luks myvm
# myvm$ sudo cryptsetup luksOpen /dev/vde cryptvol
# myvm$ sudo mount /dev/mapper/cryptvol /mnt
# 
set -e

for dep in virsh cryptsetup xmllint; do
   if ! type $dep >/dev/null; then
      echo "Missing: $dep"
      exit 1
   fi
done

error() {
    printf >&2 "\e[38;5;155m===>\e[0m\e[0;31m $@\e[0m\n"
    if [ ! -z ${crypt_vol+x} ]; then
        if [ -f "${crypt_vol}" ]; then
            pprint "Cleaning up\n"
            rm -f "${crypt_vol}"
        fi
    fi
    exit 1
}

usage() {
    echo "Usage: $(basename $0) <vm_name> [<size>] [<target>]"
    exit 1
}

pprint() {
    printf "\e[38;5;155m===>\e[0m $@"
}


[ $# -eq 0 ] && usage

if [ $(id -u) -eq 0 ]; then
    error "$(basename $0) is preferably executed as a low privileged user. $(which sudo) is used when needed."
fi


size="10G"
vm_name="$1"
vol_root="${HOME}/.cryptovols"
vol_target="vde"
crypt_vol="${vol_root}/${vm_name}-$(date +%y%m%d-%H%M)"
tmp_mapper="$(cat /proc/sys/kernel/random/uuid)"
password=$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c 64)

trap 'error "Bailing out"' ERR

# Check if vm guest exists
if [ ! "$(virsh dominfo $1 2> /dev/null)" ]; then 
    error "virsh domain $1 not found"
fi

# Set volume size if specified
if [ ! -z "$2" ]; then
    size="$2"
fi

# Set target if specified
if [ ! -z "$3" ]; then
    vol_target="$3"
fi

# Create image directory if not found
if [ ! -d "${vol_root}" ]; then
    pprint "Creating ${vol_root}\n"
    mkdir ${vol_root}
fi


pprint "Creating ${size} crypto volume ${crypt_vol}\n"
truncate -s ${size} "${crypt_vol}"
echo ${password} | sudo cryptsetup --hash sha512 --batch-mode luksFormat ${crypt_vol}
pprint "Password: ${password}\n"

pprint "Creating filesystem\n"
echo ${password} | sudo cryptsetup open ${crypt_vol} ${tmp_mapper}
sudo mkfs.ext4 /dev/mapper/${tmp_mapper} > /dev/null 2>&1
sync
sudo cryptsetup close ${tmp_mapper}

pprint "Attaching ${crypt_vol} to ${vm_name}:${vol_target}\n"
virsh attach-disk ${vm_name} ${crypt_vol} ${vol_target} --cache none > /dev/null

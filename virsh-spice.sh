#!/bin/sh
for dep in spicy virsh; do
   if ! type $dep >/dev/null; then
      echo "Missing: $dep"
      exit 1
   fi
done

if [ $# -ne 1 ]; then
    echo "Usage: $(basename $0) <domain>"
    exit 1
fi

domain=$1

# Always revert this domain
REVERT_VM="browse"

if ! virsh list --all --name | grep "$domain" >/dev/null; then
    echo "$domain not found."
    echo
    virsh list --all
    exit 1
elif ! virsh list --state-running --name | grep "$domain" >/dev/null; then
    if [ "$domain" = "$REVERT_VM" ]; then
        echo "Reverting $domain to current snapshot."
        virsh snapshot-revert $REVERT_VM --current
    fi

    virsh start "$domain"
fi

spicy -f --uri="$(virsh domdisplay $domain)"

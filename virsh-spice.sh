#!/bin/sh
#
# Virsh domain spice connect helper
#
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
running=0

# Optional space separated list of domains to revert before start
REVERT_VM=""

# Check if domain exists
if ! virsh list --all --name | grep "$domain" >/dev/null; then
    echo "$domain not found."
    echo
    virsh list --all
    exit 1
fi

# Check if domain is running
if virsh list --state-running --name | grep "$domain" >/dev/null; then
    running=1
else
    # Revert to current snapshot for domains listed in REVERT_VM
    for _domain in $REVERT_VM; do
        if [ "$domain" = "$_domain" ]; then
            echo "Reverting $domain to current snapshot."
            virsh snapshot-revert $_domain --current
        fi
    done
fi

# Start domain if it's not running
if [ $running -eq 0 ]; then
    virsh start "$domain"
fi

# Spice it up!
spicy -f --uri="$(virsh domdisplay $domain)"

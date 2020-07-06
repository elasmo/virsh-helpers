#!/bin/sh
#
# Connect to spice display
#
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
for dep in spicy virsh; do
   if ! type $dep >/dev/null; then
       error "$dep: Not found"
   fi
done

domain=$1
running=0

# Optional space separated list of domains to revert before start
REVERT_VM=""

# Check if domain exists
if ! virsh list --all --name | grep "$domain" >/dev/null; then
    error "$domain: Not found"
fi

# Check if domain is running
if virsh list --state-running --name | grep "$domain" >/dev/null; then
    running=1
else
    # Revert to current snapshot if the domain
    # is not running and is listed in REVERT_VM
    for _domain in $REVERT_VM; do
        if [ "$domain" = "$_domain" ]; then
            echo "$domain: Reverting to current snapshot"
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

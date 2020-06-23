#!/bin/sh
#
# Create domain snapshot
#
set -e

error () {
    echo "$@" 1>&2
    exit 1
}

if ! type virsh >/dev/null; then
    error "virsh: Not found"
fi

if [ $# -ne 1 ]; then
    error "Usage: $(basename $0) <domain>"
fi

virsh snapshot-create-as --domain "$1" --name "snapshot-$(date +%s)"

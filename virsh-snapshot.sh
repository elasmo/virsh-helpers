#!/bin/sh
#
# Virsh helper to create snapshot
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

virsh snapshot-create-as --domain "$1" --name "snapshot-$(date +%s)"

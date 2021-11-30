#!/bin/bash

refresh_checksum () {
    TMP_FILE=$(mktemp)
    cat "$1" | tr -s " " | cut -d" " -f2 | xargs -i bash -c "sha256sum {} >> $TMP_FILE"
    mv $TMP_FILE "$1"
}

if [ -z "$1" ]; then
    echo "$0" "[<path to checksum file>|all]"
elif [ "$1" == "all" ]; then
    export -f refresh_checksum
    find checksum/ -type f -name "*.sha256sum" | xargs -I {} bash -c 'refresh_checksum "{}"'
else
    refresh_checksum "$1"
fi

#!/bin/bash

if [ -z "$1" ]; then
    echo "$0" "<path to checksum file>"
else
    TMP_FILE=$(mktemp)
    cat "$1" | tr -s " " | cut -d" " -f2 | xargs -i bash -c "sha256sum {} >> $TMP_FILE"
    mv $TMP_FILE "$1"
fi

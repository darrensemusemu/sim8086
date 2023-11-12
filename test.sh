#!/usr/bin/env bash
#
# compare decoded output to nasm output

set -e

if [[ -z "$1" || -z "$2" ]]; then
    echo "USAGE: $0 <file1>.asm <file2>"
    exit 1
fi

file_name="$1_output"
nasm $1 -o "$file_name"
cmp $file_name $2


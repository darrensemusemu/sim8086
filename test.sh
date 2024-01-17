#!/usr/bin/env bash
#
# compare decoded output to nasm output

set -e

if [[ -z "$1" ]]; then
    echo "USAGE: $0 <file1>.asm <file2>"
    exit 1
fi


decode_output_file="/tmp/sim8086.txt"
nasm_output_file="/tmp/sim8086.asm"

zig build run -- decode $1 > "$decode_output_file"
nasm "$decode_output_file" -o "$nasm_output_file"

if ! cmp $nasm_output_file $1 ; then
    echo "FAILED: out files do not match"
else
    echo "SUCCESS: files match"
fi


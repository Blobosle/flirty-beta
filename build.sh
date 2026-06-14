#!/usr/bin/env bash
set -euo pipefail

pack_name="flirty-beta"
dist_dir="dist"
output="${dist_dir}/${pack_name}.zip"

mkdir -p "${dist_dir}"
rm -f "${output}"

COPYFILE_DISABLE=1 zip -r -X "${output}" pack.mcmeta pack.png assets

echo "Built ${output}"

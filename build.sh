#!/usr/bin/env bash
set -euo pipefail

pack_name="Flirty Beta"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dist_dir="dist"
dist_path="${repo_dir}/${dist_dir}"
build_dir="${dist_path}/.build"

versions=(
    "1.21:34:legacy"
    "1.21.1:34:legacy"
    "1.21.2:42:legacy"
    "1.21.3:42:legacy"
    "1.21.4:46:legacy"
    "1.21.5:55:legacy"
    "1.21.6:63:legacy"
    "1.21.7:64:legacy"
    "1.21.8:64:legacy"
    "1.21.9:69:range"
    "1.21.10:69:range"
    "1.21.11:75:range"
    "26.1:84:range"
    "26.1.1:84:range"
    "26.1.2:84:range"
)

mkdir -p "${dist_path}"
rm -rf "${build_dir}"
mkdir -p "${build_dir}"

for entry in "${versions[@]}"; do
    IFS=":" read -r version pack_format metadata_style <<< "${entry}"

    staging_dir="${build_dir}/${version}"
    output="${dist_path}/${pack_name} ${version}.zip"

    rm -rf "${staging_dir}" "${output}"
    mkdir -p "${staging_dir}"

    cp -R "${repo_dir}/assets" "${staging_dir}/assets"
    cp "${repo_dir}/pack.png" "${staging_dir}/pack.png"

    if [[ "${metadata_style}" == "range" ]]; then
        cat > "${staging_dir}/pack.mcmeta" <<EOF
{
    "pack": {
        "description": "Flirty Beta",
        "min_format": ${pack_format},
        "max_format": ${pack_format}
    }
}
EOF
    else
        cat > "${staging_dir}/pack.mcmeta" <<EOF
{
    "pack": {
        "description": "Flirty Beta",
        "pack_format": ${pack_format}
    }
}
EOF
    fi

    (
        cd "${staging_dir}"
        COPYFILE_DISABLE=1 zip -r -X "${output}" pack.mcmeta pack.png assets > /dev/null
    )

    echo "Built ${dist_dir}/${pack_name} ${version}.zip"
done

rm -rf "${build_dir}"

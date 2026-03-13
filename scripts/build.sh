#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${repo_root}/build"

if command -v nproc >/dev/null 2>&1; then
  jobs="$(nproc)"
elif command -v sysctl >/dev/null 2>&1; then
  jobs="$(sysctl -n hw.logicalcpu)"
else
  jobs=1
fi

echo "Select build type:"
select build_type in Debug Release; do
  case "${build_type}" in
    Debug|Release)
      break
      ;;
    *)
      echo "Enter 1 for Debug or 2 for Release."
      ;;
  esac
done

mkdir -p "${build_dir}"
cd "${build_dir}"

cmake .. -DCMAKE_BUILD_TYPE="${build_type}"
cmake --build . -j"${jobs}"

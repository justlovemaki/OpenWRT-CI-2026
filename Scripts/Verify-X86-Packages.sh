#!/bin/bash
# Fail closed if Kconfig drops a requested package or an image omits it.
set -euo pipefail
mode=${1:?config or manifest}
target=${2:?configuration or firmware directory}
root=${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}
required="$root/Config/X86-required-packages.txt"
test -s "$required"
failed=0
check_manifest() {
  local file=$1 pkg
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if ! awk -v p="$pkg" '$1==p {found=1} END {exit !found}' "$file"; then
      echo "::error::Missing firmware package $pkg in $file"
      failed=1
    fi
  done < "$required"
  if grep -Eq '^luci-(app-homeproxy|i18n-homeproxy-zh-cn)([[:space:]]|$)' "$file"; then
    echo "::error::HomeProxy must not be included in $file"
    failed=1
  fi
}
case "$mode" in
  config)
    test -f "$target"
    while IFS= read -r pkg; do
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      if ! grep -Fxq "CONFIG_PACKAGE_${pkg}=y" "$target"; then
        echo "::error::Required package not built into image: $pkg"
        failed=1
      fi
    done < "$required"
    if grep -Eq '^CONFIG_PACKAGE_luci-(app-homeproxy|i18n-homeproxy-zh-cn)=[ym]$' "$target"; then
      echo '::error::HomeProxy unexpectedly selected'
      failed=1
    fi
    ;;
  manifest)
    mapfile -d '' manifests < <(find "$target" -type f -name '*.manifest' -print0)
    if (( ${#manifests[@]} == 0 )); then
      echo '::error::No firmware manifest generated'
      exit 1
    fi
    for file in "${manifests[@]}"; do check_manifest "$file"; done
    ;;
  *) echo "Unknown mode: $mode" >&2; exit 2;;
esac
exit "$failed"

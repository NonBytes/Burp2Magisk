#!/bin/bash
set -euo pipefail
export LC_ALL=C
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
(($# >= 2)) || {
  echo 'Expected an output directory and at least one certificate' >&2
  exit 1
}
base=$(cd -- "$(dirname -- "$0")" && pwd)
out=$1
shift
[[ ! -e "$out" && ! -L "$out" ]] || { echo 'Output already exists' >&2; exit 1; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/b2m.XXXXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

module="$tmp/module"
mkdir "$module"
mkdir -p "$module/system/etc/security/cacerts"

hashes=()
index=0
for input in "$@"; do
  index=$((index + 1))
  /bin/bash "$base/burp-ca-to-android.sh" -o "$tmp/converted-$index" -- "$input"
  certs=("$tmp/converted-$index/"*.0)
  [[ ${#certs[@]} = 1 && -f ${certs[0]} ]]
  name=${certs[0]##*/}
  hash=${name%.0}
  dest="$module/system/etc/security/cacerts/$name"
  if [[ -e "$dest" ]]; then
    cmp -s "${certs[0]}" "$dest" \
      || { echo "Two different certificates hash to the same name: $hash" >&2; exit 1; }
    continue
  fi
  cp "${certs[0]}" "$dest"
  hashes+=("$hash")
done
(( ${#hashes[@]} >= 1 )) || { echo 'No certificates were produced' >&2; exit 1; }

# A deterministic module id derived from the sorted set of hashes lets Magisk
# upgrade the same module in place when the same certificate set is rebuilt,
# while a different set of certificates gets its own module id.
sorted_hashes=$(printf '%s\n' "${hashes[@]}" | sort)
module_id=burp_ca_$(printf '%s' "$sorted_hashes" | /usr/bin/shasum -a 256 | cut -c1-8)
count=${#hashes[@]}

for name in post-fs-data.sh mount-ca.sh; do
  cp "$base/ModuleTemplate/$name" "$module/$name"
done
cp "$base/ModuleTemplate/LICENSE" "$module/LICENSE"
cat > "$module/module.prop" <<PROP
id=$module_id
name=Burp CA ($count certs)
version=1.0
versionCode=1
author=Burp2Magisk
description=Burp2Magisk custom CA module for Android system and Conscrypt trust stores ($count certificate(s)).
PROP
cat > "$module/customize.sh" <<'CUSTOMIZE'
ui_print "Installing supplied CA certificate(s)"
for cert in "$MODPATH"/system/etc/security/cacerts/*.0; do
  name=${cert##*/}
  for store in /system/etc/security/cacerts /apex/com.android.conscrypt/cacerts; do
    if [ -f "$store/$name" ] && ! cmp -s "$cert" "$store/$name"; then
      abort "CA filename collision: $store/$name"
    fi
  done
done
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/mount-ca.sh" 0 0 0755
CUSTOMIZE
chmod 0755 "$module/post-fs-data.sh" "$module/mount-ca.sh"
chmod 0644 "$module/module.prop" "$module/customize.sh" "$module"/system/etc/security/cacerts/*.0
(cd "$module" && /usr/bin/zip -q -r "$tmp/BurpCA-Magisk.zip" .)
/usr/bin/unzip -tq "$tmp/BurpCA-Magisk.zip" >/dev/null
mkdir "$out"
cp "$tmp/BurpCA-Magisk.zip" "$out/"
echo 'ZIP created successfully.'

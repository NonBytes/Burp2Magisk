#!/bin/bash
set -euo pipefail
export LC_ALL=C
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
(($# == 2)) || {
  echo 'Expected an output directory and one certificate' >&2
  exit 1
}
base=$(cd -- "$(dirname -- "$0")" && pwd)
out=$1
input=$2
[[ ! -e "$out" && ! -L "$out" ]] || { echo 'Output already exists' >&2; exit 1; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/b2m.XXXXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

module="$tmp/module"
mkdir "$module"
mkdir -p "$module/system/etc/security/cacerts"

/bin/bash "$base/burp-ca-to-android.sh" -o "$tmp/converted" -- "$input"
certs=("$tmp/converted/"*.0)
[[ ${#certs[@]} = 1 && -f ${certs[0]} ]]
name=${certs[0]##*/}
hash=${name%.0}
cp "${certs[0]}" "$module/system/etc/security/cacerts/$name"

module_id="burp_ca_$hash"

for name in post-fs-data.sh mount-ca.sh; do
  cp "$base/ModuleTemplate/$name" "$module/$name"
done
cp "$base/ModuleTemplate/LICENSE" "$module/LICENSE"
cat > "$module/module.prop" <<PROP
id=$module_id
name=Burp CA ($hash)
version=1.0
versionCode=1
author=Burp2Magisk
description=Burp2Magisk custom CA module for Android system and Conscrypt trust stores.
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

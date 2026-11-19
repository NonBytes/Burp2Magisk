#!/usr/bin/env bash
# Read-only preview of one CA certificate: never writes any output file.
set -euo pipefail
export LC_ALL=C

[[ $# = 1 ]] || { echo 'Expected exactly one certificate path' >&2; exit 1; }
input=$1
command -v openssl >/dev/null 2>&1 || { echo 'openssl is required; install OpenSSL and retry' >&2; exit 1; }
[[ -f "$input" && -r "$input" && -s "$input" ]] \
  || { echo "ไม่สามารถอ่านไฟล์ได้: $input" >&2; exit 1; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/b2m-info.XXXXXXXX") || { echo 'Cannot create temporary directory' >&2; exit 1; }
trap 'rm -rf -- "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if openssl x509 -inform PEM -in "$input" -outform PEM -out "$tmp/ca.pem" 2>/dev/null; then
  count=$(awk '/-----BEGIN (TRUSTED )?CERTIFICATE-----/ {n++} END {print n+0}' "$input")
  [[ "$count" = 1 ]] || { echo 'ไฟล์ PEM มีหลาย certificate รวมกัน (bundle) ไม่รองรับ' >&2; exit 1; }
  if awk '/-----BEGIN .*PRIVATE KEY-----/ {found=1} END {exit !found}' "$input"; then
    echo 'ไฟล์มี private key รวมอยู่ด้วย กรุณา export เฉพาะ certificate' >&2
    exit 1
  fi
elif openssl x509 -inform DER -in "$input" -outform PEM -out "$tmp/ca.pem" 2>/dev/null; then
  :
else
  echo 'ไม่ใช่ไฟล์ certificate แบบ DER หรือ PEM ที่อ่านได้' >&2
  exit 1
fi

openssl x509 -in "$tmp/ca.pem" -noout -text >"$tmp/details" 2>/dev/null \
  || { echo 'ไม่สามารถตรวจสอบ certificate ได้' >&2; exit 1; }
# Inspect only Basic Constraints, not an unrelated field containing CA:TRUE.
awk '
  /X509v3 Basic Constraints:/ {inside=1; next}
  inside && /CA:TRUE([,[:space:]]|$)/ {valid=1}
  inside && /X509v3 .*:/ {inside=0}
  inside && /Signature Algorithm:/ {inside=0}
  END {exit !valid}
' "$tmp/details" || { echo 'ไม่มี Basic Constraints CA:TRUE จึงไม่ใช่ CA certificate' >&2; exit 1; }

hash=$(openssl x509 -in "$tmp/ca.pem" -subject_hash_old -noout 2>/dev/null) \
  || { echo 'คำนวณ subject hash ไม่ได้' >&2; exit 1; }
[[ "$hash" =~ ^[0-9a-f]{8}$ ]] || { echo "Unexpected subject hash: $hash" >&2; exit 1; }
subject=$(openssl x509 -in "$tmp/ca.pem" -noout -subject -nameopt sep_comma_plus,utf8 2>/dev/null) \
  || { echo 'อ่าน subject ไม่ได้' >&2; exit 1; }
subject=${subject#subject=}
not_after=$(openssl x509 -in "$tmp/ca.pem" -noout -enddate 2>/dev/null) \
  || { echo 'อ่านวันหมดอายุไม่ได้' >&2; exit 1; }
not_after=${not_after#notAfter=}
expired=no
openssl x509 -in "$tmp/ca.pem" -checkend 0 -noout >/dev/null 2>&1 || expired=yes

printf 'SUBJECT=%s\n' "$subject"
printf 'NOT_AFTER=%s\n' "$not_after"
printf 'HASH=%s\n' "$hash"
printf 'EXPIRED=%s\n' "$expired"

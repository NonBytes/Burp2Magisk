#!/usr/bin/env bash
# Convert one DER/PEM CA certificate; never install it or overwrite outputs.
set -euo pipefail
export LC_ALL=C
umask 022

usage() {
  cat <<'HELP'
Usage: burp-ca-to-android.sh [-o OUTPUT_DIR] [--] CERTIFICATE
       burp-ca-to-android.sh -h | --help

Accept one X.509 CA certificate in DER or PEM format.
Require X509v3 Basic Constraints containing CA:TRUE.
Write burp-ca.pem and <subject_hash_old>.0 (both PEM).
Default output directory: ./android-ca
Existing output files are never overwritten. No installation is performed.

Examples:
  bash burp-ca-to-android.sh burp.der
  bash burp-ca-to-android.sh -o "converted certs" burp.pem
HELP
}
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
out=./android-ca
input=
while (($#)); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -o|--output-dir)
      (($# >= 2)) || die "$1 requires a directory"
      [[ -n "$2" ]] || die 'Output directory cannot be empty'
      out=$2; shift 2 ;;
    --) shift; break ;;
    -*) die "Unknown option: $1 (use --help)" ;;
    *) [[ -z "$input" ]] || die 'Provide exactly one certificate'; input=$1; shift ;;
  esac
done
while (($#)); do
  [[ -z "$input" ]] || die 'Provide exactly one certificate'
  input=$1; shift
done
[[ -n "$input" ]] || { usage >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || die 'openssl is required; install OpenSSL and retry'
# Prefix relative paths so filenames beginning with a dash remain safe.
[[ "$input" = /* ]] || input=./$input
[[ "$out" = /* ]] || out=./$out
[[ -f "$input" && -r "$input" && -s "$input" ]] || die "Input must be a readable, non-empty file: $input"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/burp-ca.XXXXXXXX") || die 'Cannot create temporary directory'
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if openssl x509 -inform PEM -in "$input" -outform PEM -out "$tmp/ca.pem" 2>"$tmp/parse.err"; then
  format=PEM
  count=$(awk '/-----BEGIN (TRUSTED )?CERTIFICATE-----/ {n++} END {print n+0}' "$input")
  [[ "$count" = 1 ]] || die 'PEM bundles are not supported; provide exactly one certificate'
  if awk '/-----BEGIN .*PRIVATE KEY-----/ {found=1} END {exit !found}' "$input"; then
    die 'Input contains a private key; export only the CA certificate'
  fi
elif openssl x509 -inform DER -in "$input" -outform PEM -out "$tmp/ca.pem" 2>"$tmp/parse.err"; then
  format=DER
else
  die 'Cannot parse input as an X.509 certificate in PEM or DER format'
fi

openssl x509 -in "$tmp/ca.pem" -noout -text >"$tmp/details" 2>"$tmp/parse.err" || die 'Cannot inspect certificate'
# Inspect only Basic Constraints, not an unrelated field containing CA:TRUE.
awk '
  /X509v3 Basic Constraints:/ {inside=1; next}
  inside && /CA:TRUE([,[:space:]]|$)/ {valid=1}
  inside && /X509v3 .*:/ {inside=0}
  inside && /Signature Algorithm:/ {inside=0}
  END {exit !valid}
' "$tmp/details" || die 'Certificate must have X509v3 Basic Constraints with CA:TRUE'

hash=$(openssl x509 -in "$tmp/ca.pem" -subject_hash_old -noout 2>"$tmp/parse.err") || die 'Cannot compute subject_hash_old; check OpenSSL legacy hash support'
[[ "$hash" =~ ^[0-9a-f]{8}$ ]] || die "Unexpected subject hash: $hash"
openssl x509 -in "$tmp/ca.pem" -noout -subject -issuer -dates -fingerprint -sha256 >"$tmp/summary" || die 'Cannot read certificate summary'
if ! openssl x509 -in "$tmp/ca.pem" -checkend 0 -noout >/dev/null 2>&1; then
  printf 'Warning: certificate has expired (or its expiry could not be checked).\n' >&2
fi

mkdir -p -- "$out" || die "Cannot create output directory: $out"
[[ -d "$out" && -w "$out" ]] || die "Output directory is not writable: $out"
for name in burp-ca.pem "$hash.0"; do
  [[ ! -e "$out/$name" && ! -L "$out/$name" ]] || die "Output already exists: $out/$name; choose another directory"
done
# Stage on the destination filesystem, then publish with exclusive hard links.
stage=$(mktemp -d "$out/.burp-ca.XXXXXXXX") || die 'Cannot stage output files'
cleanup() { rm -rf -- "$tmp" "${stage:-}"; }
cp -- "$tmp/ca.pem" "$stage/cert" || die 'Cannot stage certificate'
chmod 0644 "$stage/cert" || die 'Cannot set certificate permissions'
ln -- "$stage/cert" "$out/burp-ca.pem" || die 'Cannot write PEM output (possibly created by another process)'
ln -- "$stage/cert" "$out/$hash.0" || die 'Cannot write hash output; PEM output was already created'
printf 'Input format: %s\nSubject hash (old): %s\n' "$format" "$hash"
cat "$tmp/summary"
printf '\nCreated:\n  %s/burp-ca.pem\n  %s/%s.0\nNo certificate was installed.\n' "$out" "$out" "$hash"

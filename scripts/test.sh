#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p work/module-cache
fixture=$(mktemp -d "$PWD/work/integration.XXXXXXXX")
trap 'rm -rf -- "$fixture"' EXIT
for kind in ca ca2 leaf; do
  constraint=TRUE
  [[ $kind = leaf ]] && constraint=FALSE
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$fixture/$kind.key" -out "$fixture/$kind.pem" -days 1 \
    -subj "/CN=Burp2Magisk $kind test" \
    -addext "basicConstraints=critical,CA:$constraint" >"$fixture/generate.log" 2>&1
done
/usr/bin/openssl x509 -in "$fixture/ca.pem" -outform DER -out "$fixture/ca.der"
cp "$fixture/ca.der" "$fixture/ใบรับรอง 'quoted' \$name.der"
cat "$fixture/ca.pem" "$fixture/ca.pem" > "$fixture/bundle.pem"
printf 'invalid certificate' > "$fixture/malformed.der"
/usr/bin/swiftc Sources/Services/ModuleBuilder.swift Tests/main.swift \
  -module-cache-path "$PWD/work/module-cache" -o "$fixture/integration-tests"
"$fixture/integration-tests" "$PWD/Resources" "$fixture"

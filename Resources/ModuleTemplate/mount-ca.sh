#!/system/bin/sh
# Burp2Magisk's volatile Conscrypt overlay. The underlying APEX files stay untouched.
set -eu
MODDIR=${0%/*}
store=/apex/com.android.conscrypt/cacerts
certdir="$MODDIR/system/etc/security/cacerts"
[ -d "$store" ] || exit 0
snapshot=$(mktemp -d "$MODDIR/.ca-snapshot.XXXXXX")
mounted=0
success=0
cleanup() {
    result=$?
    if [ "$mounted" = 1 ] && [ "$success" != 1 ]; then
        umount "$store" || echo 'ERROR: rollback unmount failed'
    fi
    rm -rf "$snapshot"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Preserve the entire existing store before overlaying, including other CAs.
cp -a "$store/." "$snapshot/"
count=0
for cert in "$snapshot"/*; do
    [ -f "$cert" ] || continue
    count=$((count + 1))
done
[ "$count" -gt 0 ] || { echo 'ERROR: empty source CA store'; exit 1; }
for cert in "$certdir"/*.0; do
    [ -f "$cert" ] || { echo 'ERROR: no module certificate'; exit 1; }
    name=${cert##*/}
    if [ -e "$snapshot/$name" ] && ! cmp -s "$cert" "$snapshot/$name"; then
        echo "ERROR: CA collision: $name"; exit 1
    fi
    cp "$cert" "$snapshot/$name"
done
context=$(ls -Zd "$store" | awk '{print $1}')
case "$context" in
    u:object_r:*) ;;
    *) echo 'ERROR: cannot determine CA store SELinux context'; exit 1 ;;
esac
mount -t tmpfs -o mode=0755 tmpfs "$store"
mounted=1
cp -a "$snapshot/." "$store/"
chown -R 0:0 "$store"
chmod 0755 "$store"
for cert in "$store"/*; do
    [ ! -f "$cert" ] || chmod 0644 "$cert"
done
chcon -R "$context" "$store"
# Confirm every saved file made it to the overlay before accepting it.
for cert in "$snapshot"/*; do
    [ ! -f "$cert" ] || cmp -s "$cert" "$store/${cert##*/}"
done
success=1
echo "Burp2Magisk: Conscrypt overlay ready; preserved $count existing CA files."

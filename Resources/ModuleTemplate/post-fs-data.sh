#!/system/bin/sh
# Burp2Magisk: run the APEX overlay in init's namespace before Android starts apps.
MODDIR=${0%/*}
exec >> "$MODDIR/boot.log" 2>&1
printf '\nBurp2Magisk boot: %s\n' "$(date)"
BB=/data/adb/magisk/busybox
if [ ! -x "$BB" ]; then
    echo 'ERROR: Magisk BusyBox unavailable'; exit 1
fi
if [ -d /apex/com.android.conscrypt/cacerts ]; then
    ASH_STANDALONE=1 "$BB" nsenter -t 1 -m -- "$BB" sh "$MODDIR/mount-ca.sh"
else
    echo 'No Conscrypt APEX store; using Magisk system overlay only.'
fi

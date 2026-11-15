#!/usr/bin/env bash
# Accepts the APK only when apksigner verifies it AND its signing certificate (lineage) is Google's
# com.google.android.googlequicksearchbox key. Prints "versionName versionCode".
set -euo pipefail
APK=${1:?apk}
GOOGLE_CERT=f0fd6c5b410f25cb25c3b53346c8972fae30f8ee7411df910480ad6b2d60db83   # original GSA signing cert (SHA-256)
C=$(mktemp); trap 'rm -f "$C"' EXIT
apksigner verify --print-certs "$APK" > "$C"
grep -qi "certificate SHA-256 digest: $GOOGLE_CERT" "$C" || { cat "$C" >&2; echo "NOT signed by Google" >&2; exit 1; }
b=$(aapt2 dump badging "$APK" 2>/dev/null | sed -n 1p)
pkg=$(echo "$b" | grep -oE "^package: name='[^']+'" | cut -d"'" -f2)
vc=$(echo "$b" | grep -oE " versionCode='[^']+'" | cut -d"'" -f2)
vn=$(echo "$b" | grep -oE " versionName='[^']+'" | cut -d"'" -f2)
[ "$pkg" = com.google.android.googlequicksearchbox ] || { echo "wrong package $pkg" >&2; exit 1; }
[ -n "$vc" ] && [ -n "$vn" ] || { echo "no version" >&2; exit 1; }
echo "$vn $vc"

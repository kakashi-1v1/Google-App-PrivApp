#!/usr/bin/env bash
# Downloads the newest stable Google app (com.google.android.googlequicksearchbox), arm64 "ve" single APK (nodpi),
# from APKMirror. Prints "<version>" and writes <out>. The signature is checked separately (scripts/verify_google.sh).
# fetch_apkmirror.sh --version  -> only prints the newest stable version
set -euo pipefail
OUT=${1:?out apk}
UA='Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0'
B=https://www.apkmirror.com
get() { curl -fsSL --retry 3 --retry-delay 5 -A "$UA" "$1"; }

page=$(get "$B/uploads/?appcategory=google-search")
# newest stable release: "Google App 17.74.20" (no beta / alpha)
rel=$(printf '%s' "$page" | grep -oE 'class="fontBlack" href="/apk/google-inc/google-search/google-app-[0-9-]+-release/">Google App [0-9.]+</a>' \
      | sed -E 's/.*href="([^"]+)">Google App ([0-9.]+)<.*/\2 \1/' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -n1)
[ -n "$rel" ] || { echo "no stable release found" >&2; exit 1; }
ver=${rel%% *}; path=${rel#* }
echo "release $ver: $path" >&2
[ "$OUT" = --version ] && { echo "$ver"; exit 0; }

relpage=$(get "$B$path")
# variant row: "<ver>.ve.arm64" APK (not BUNDLE), nodpi
var=$(printf '%s' "$relpage" | python3 -c '
import re, sys, html
s = sys.stdin.read()
for r in re.split(r"<div class=\"table-row headerFont\">", s)[1:]:
    m = re.search(r"href=\"(/apk/[^\"]+-android-apk-download/)\"", r)
    t = " ".join(html.unescape(re.sub(r"<[^>]+>", " ", r)).split())
    if m and re.search(r"\.ve\.arm64 APK\b", t) and "nodpi" in t and "arm64-v8a" in t:
        print(m.group(1)); break
')
[ -n "$var" ] || { echo "no ve.arm64 nodpi APK variant in $ver" >&2; exit 1; }
echo "variant: $var" >&2
k=$(get "$B$var" | grep -oE 'href="/apk/[^"]*/download/\?key=[^"]*"' | head -n1 | sed 's/^href="//; s/"$//; s/&amp;/\&/g')
[ -n "$k" ] || { echo "no download key" >&2; exit 1; }
d=$(get "$B$k" | grep -oE 'href="/wp-content/themes/APKMirror/download\.php\?[^"]*"' | head -n1 | sed 's/^href="//; s/"$//; s/&amp;/\&/g')
[ -n "$d" ] || { echo "no download link" >&2; exit 1; }
curl -fL --retry 3 --retry-delay 5 -A "$UA" -e "$B$k" -o "$OUT" "$B$d"
echo "$ver"

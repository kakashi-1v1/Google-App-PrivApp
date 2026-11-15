#!/usr/bin/env bash
# build_module.sh <out zip> [<verified Velvet.apk> <versionName> <versionCode>]
#   without an APK: online zip (the Google app is downloaded while flashing)
#   with an APK:    offline zip (bundles that Google app + its privapp allowlist)
set -euo pipefail
OUT=$1
R=$(cd "$(dirname "$0")/.." && pwd)
rm -f "$OUT"
(cd "$R/module" && zip -qr -9 -D "$OUT" META-INF customize.sh module.prop service.sh uninstall.sh \
    kashi_overlay.sh kashi_apkeditor.jar KashiGoogleAssistOverlay.apk LICENSE-APKEditor.txt \
    com.google.android.contextual_search.xml)
if [ $# -ge 4 ]; then
    S=$(mktemp -d)
    cp -f "$2" "$S/Velvet.apk"
    printf 'GAPP_VERSION_NAME="%s"\nGAPP_VERSION_CODE="%s"\n' "$3" "$4" > "$S/gapp.ver"
    bash "$R/scripts/make_privapp.sh" "$S/Velvet.apk" "$S/privapp-permissions.xml"
    (cd "$S" && zip -q -9 -D "$OUT" gapp.ver privapp-permissions.xml && zip -q -0 -D "$OUT" Velvet.apk)
    rm -rf "$S"
fi
ls -la "$OUT"

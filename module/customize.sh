#!/system/bin/sh
# Google App as a privileged system app + Google as default assistant / Circle to Search provider.
# The Google app inside this zip is the official, Google-signed build (checked by the release workflow).
SKIPUNZIP=1
PKG=com.google.android.googlequicksearchbox

ui_print " "
ui_print "  Google App PrivApp - by kashi"
ui_print " "
[ "$BOOTMODE" = true ] || abort "! Flash this from the Magisk / KernelSU / APatch app."
[ "$API" -ge 30 ] || abort "! Android 11 or newer is required."
[ "$ARCH" = arm64 ] || abort "! arm64 devices only (this zip carries the arm64 Google app)."

W="$TMPDIR/kashi_gapp"
rm -rf "$W"; mkdir -p "$W/art/dalvik-cache"
unzip -qo "$ZIPFILE" module.prop system.prop service.sh uninstall.sh -d "$MODPATH" >&2 || abort "! Unzip failed"
unzip -qo "$ZIPFILE" kashi_overlay.sh kashi_apkeditor.jar KashiGoogleAssistOverlay.apk com.google.android.contextual_search.xml -d "$W" >&2 || abort "! Unzip failed"
. "$W/kashi_overlay.sh"

# ---------------------------------------------------------------- Google app: bundled (offline zip) or downloaded
if unzip -l "$ZIPFILE" Velvet.apk 2>/dev/null | grep -q Velvet.apk; then
    ui_print "- Offline package: using the bundled Google app"
    unzip -qo "$ZIPFILE" gapp.ver privapp-permissions.xml -d "$W" >&2 || abort "! Unzip failed"
    . "$W/gapp.ver"   # GAPP_VERSION_NAME, GAPP_VERSION_CODE
    unzip -qo "$ZIPFILE" Velvet.apk -d "$W" >&2 || abort "! Unzip of the Google app failed (free storage?)"
    APK="$W/Velvet.apk"
else
# latest.json is written by this repo's workflow: the APK there was downloaded from APKMirror and only published
# after apksigner verified it is signed with Google's certificate. Here the SHA-256 of that exact file is checked.
REPO=https://raw.githubusercontent.com/kakashi-1v1/Google-App-PrivApp/main
WGET=""
for b in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox "$(command -v busybox)"; do
    [ -n "$b" ] && [ -x "$b" ] && "$b" wget --help >/dev/null 2>&1 && { WGET="$b wget"; break; }
done
[ -n "$WGET" ] || { command -v wget >/dev/null 2>&1 && WGET=wget; }
[ -n "$WGET" ] || abort "! No downloader found (busybox wget)."
jget() { sed -n "s/^ *\"$1\": *\"\{0,1\}\([^\",]*\)\"\{0,1\},\{0,1\} *$/\1/p" "$W/latest.json" | head -n1; }

ui_print "- Checking the newest Google app..."
$WGET -q -O "$W/latest.json" "$REPO/latest.json?t=$(date +%s)" 2>/dev/null || abort "! No internet connection (could not reach github.com)."
GAPP_VERSION_NAME=$(jget versionName); GAPP_VERSION_CODE=$(jget versionCode)
APK_URL=$(jget apk); APK_SHA=$(jget apkSha256); APK_SIZE=$(jget apkSize)
PP_URL=$(jget privapp); PP_SHA=$(jget privappSha256)
[ -n "$APK_URL" ] && [ -n "$APK_SHA" ] && [ -n "$GAPP_VERSION_CODE" ] || abort "! latest.json could not be read."
[ "$APK_SIZE" -gt 0 ] 2>/dev/null || APK_SIZE=0

kashi_bar() {   # <percent>
    _n=$(( $1 / 5 )); _b=""; _i=0
    while [ $_i -lt 20 ]; do [ $_i -lt $_n ] && _b="$_b#" || _b="$_b-"; _i=$((_i + 1)); done
    echo "$_b"
}
kashi_download() {   # <url> <out> <expected size> <sha256>
    rm -f "$2" "$2.rc"
    ( $WGET -q -O "$2" "$1" 2>/dev/null; echo $? > "$2.rc" ) &
    _last=-1; _t=0
    while [ ! -f "$2.rc" ]; do
        sleep 1; _t=$((_t + 1))
        _cur=$(stat -c %s "$2" 2>/dev/null || echo 0)
        if [ "$3" -gt 0 ]; then
            _pct=$(( _cur * 100 / $3 )); [ $_pct -gt 100 ] && _pct=100
            if [ $(( _pct / 5 )) -ne $_last ]; then
                _last=$(( _pct / 5 ))
                ui_print "  [$(kashi_bar $_pct)] $_pct%  $(( _cur / 1048576 )) / $(( $3 / 1048576 )) MB"
            fi
        elif [ $(( _t % 5 )) -eq 0 ]; then ui_print "  $(( _cur / 1048576 )) MB"; fi
    done
    [ "$(cat "$2.rc")" = 0 ] || return 1
    [ "$(sha256sum "$2" | cut -d' ' -f1)" = "$4" ]
}

CACHE=/data/local/tmp/kashi_gapp; mkdir -p "$CACHE"
APK="$CACHE/Velvet-$GAPP_VERSION_CODE.apk"
if [ -f "$APK" ] && [ "$(sha256sum "$APK" | cut -d' ' -f1)" = "$APK_SHA" ]; then
    ui_print "- Google app $GAPP_VERSION_NAME already downloaded"
else
    rm -f "$CACHE"/Velvet-*.apk
    ui_print "- Downloading Google app $GAPP_VERSION_NAME ($(( APK_SIZE / 1048576 )) MB)"
    kashi_download "$APK_URL" "$APK.part" "$APK_SIZE" "$APK_SHA" || { rm -f "$APK.part"*; abort "! Download failed or the file is damaged, try again."; }
    mv -f "$APK.part" "$APK"; rm -f "$APK.part.rc"
    ui_print "  checksum OK"
fi
kashi_download "$PP_URL" "$W/privapp-permissions.xml" 0 "$PP_SHA" >/dev/null || abort "! Could not download the permission list."
fi

# partition path -> module path (/product/x -> system/product/x, /system/x -> system/x)
kashi_modpath() { case "$1" in /system/*) echo "$MODPATH$1" ;; *) echo "$MODPATH/system$1" ;; esac; }
# stock file under an older mounted copy of this module (private mount namespace, unmount layers until it shows)
kashi_stock_copy() {   # <path on device> <dest>
    _old=$(kashi_modpath "$1" | sed "s|^$MODPATH|/data/adb/modules/$MODID|")
    if [ -f "$_old" ]; then
        unshare -m --propagation private sh -c '
            p="$1"
            while :; do
                if [ -f "$1" ] && ! cmp -s "$1" "$3"; then cp -f "$1" "$2"; exit 0; fi
                [ "$p" = "/" ] && exit 1
                umount -l "$p" 2>/dev/null
                p=$(dirname "$p")
            done' kashi "$1" "$2" "$_old" 2>/dev/null
        [ -s "$2" ] && ! cmp -s "$2" "$_old" && return 0
        rm -f "$2"; return 1
    fi
    cp -f "$1" "$2"
}

# ---------------------------------------------------------------- Google app
ui_print "- Google app: $GAPP_VERSION_NAME ($GAPP_VERSION_CODE)"
SYS_DIR=""; SYS_CODE=0
_dump="$W/pkg.txt"
dumpsys package "$PKG" > "$_dump" 2>/dev/null
# system copy hidden by an update in /data
SYS_DIR=$(awk '/^Hidden system packages:/{h=1} h && /codePath=/{sub(/.*codePath=/,""); print; exit}' "$_dump")
SYS_CODE=$(awk '/^Hidden system packages:/{h=1} h && /versionCode=/{sub(/.*versionCode=/,""); sub(/ .*/,""); print; exit}' "$_dump")
if [ -z "$SYS_DIR" ]; then   # not updated: the running copy may itself be the system one
    _p=$(pm path "$PKG" 2>/dev/null | head -n1 | sed 's/^package://')
    case "$_p" in ""|/data/*) ;; *) SYS_DIR=$(dirname "$_p")
        SYS_CODE=$(awk '/versionCode=/{sub(/.*versionCode=/,""); sub(/ .*/,""); print; exit}' "$_dump") ;; esac
fi
[ -n "$SYS_CODE" ] || SYS_CODE=0
# what the ROM had, saved on the first install (afterwards our own mounted copy would show up as the system one)
_state="/data/adb/modules/$MODID/kashi_rom_state"
if [ -f "$_state" ]; then . "$_state"; SYS_DIR="$ROM_DIR"; SYS_CODE="$ROM_CODE"
else ROM_DIR="$SYS_DIR"; ROM_CODE="$SYS_CODE"; fi
printf 'ROM_DIR="%s"\nROM_CODE="%s"\n' "$SYS_DIR" "$SYS_CODE" > "$MODPATH/kashi_rom_state"

TARGET=/product/priv-app/Velvet
case "$SYS_DIR" in
    "") ui_print "- Google app is not a system app on this ROM, adding it to $TARGET" ;;
    */priv-app/*) TARGET="$SYS_DIR"; ui_print "- ROM has Google as priv-app in $SYS_DIR" ;;
    *) ui_print "- ROM has Google as a normal system app in $SYS_DIR, moving it to $TARGET"
       mkdir -p "$(kashi_modpath "$SYS_DIR")"; touch "$(kashi_modpath "$SYS_DIR")/.replace" ;;
esac
PART=${TARGET#/}; PART=${PART%%/*}           # product / system / system_ext
if [ "$SYS_CODE" -gt "$GAPP_VERSION_CODE" ] 2>/dev/null && case "$SYS_DIR" in */priv-app/*) true ;; *) false ;; esac; then
    ui_print "- ROM's own priv-app Google is newer ($SYS_CODE), keeping it"
else
    _d=$(kashi_modpath "$TARGET")
    mkdir -p "$_d"
    ui_print "- Installing Google app to $TARGET"
    cp -f "$APK" "$_d/$(basename "$TARGET").apk" || abort "! Copy failed (free storage?)"
    touch "$_d/.replace"       # hides the ROM's apk + stale oat of that folder
    case "$PART" in system) _pd="$MODPATH/system/etc/permissions" ;; *) _pd="$MODPATH/system/$PART/etc/permissions" ;; esac
    mkdir -p "$_pd"
    cp -f "$W/privapp-permissions.xml" "$_pd/privapp-permissions-kashi-google.xml"
    KASHI_CLEAN="$(basename "$TARGET")"
fi

# ---------------------------------------------------------------- overlay (default assistant + contextual search)
# ART runtime for APKEditor (same setup as the FPS / signature modules)
_cp="$W/classpath.env"; : > "$_cp"
if ! /apex/com.android.sdkext/bin/derive_classpath "$_cp" 2>/dev/null || [ ! -s "$_cp" ]; then
    if [ -r /data/system/environ/classpath ]; then tr '\0' '\n' < /data/system/environ/classpath > "$_cp" 2>/dev/null
    else
        for _p in $(pidof zygote64 2>/dev/null) $(pidof zygote 2>/dev/null) $(pidof system_server 2>/dev/null); do
            [ -r "/proc/$_p/environ" ] || continue
            tr '\0' '\n' < "/proc/$_p/environ" 2>/dev/null | sed -n 's/^\(BOOTCLASSPATH\|DEX2OATBOOTCLASSPATH\)=/export \1 /p' > "$_cp"
            [ -s "$_cp" ] && break
        done
    fi
fi
while read -r _kw _name _val; do [ "$_kw" = export ] && [ -n "$_val" ] && export "$_name=$_val"; done < "$_cp"
[ -n "$DEX2OATBOOTCLASSPATH" ] || export DEX2OATBOOTCLASSPATH="$BOOTCLASSPATH"
export ANDROID_ROOT="${ANDROID_ROOT:-/system}" ANDROID_ART_ROOT="${ANDROID_ART_ROOT:-/apex/com.android.art}"
export ANDROID_I18N_ROOT="${ANDROID_I18N_ROOT:-/apex/com.android.i18n}" ANDROID_TZDATA_ROOT="${ANDROID_TZDATA_ROOT:-/apex/com.android.tzdata}"
export ANDROID_DATA="$W/art"
DVM=
for d in /apex/com.android.art/bin/dalvikvm64 /apex/com.android.art/bin/dalvikvm /system/bin/dalvikvm64 /system/bin/dalvikvm; do
    if [ -x "$d" ] && "$d" -Xnoimage-dex2oat -showversion >/dev/null 2>&1; then DVM="$d"; break; fi
done
kashi_apkeditor() {
    _rc=0
    "$DVM" -Xmx512m -Xnoimage-dex2oat -Djava.io.tmpdir="$W" -cp "$W/kashi_apkeditor.jar" com.reandroid.apkeditor.Main "$@" || _rc=$?
    if [ "$_rc" -ge 128 ]; then   # no JIT memory in this install context (seen on KernelSU): interpreter
        _rc=0
        "$DVM" -Xint -Xmx512m -Xnoimage-dex2oat -Djava.io.tmpdir="$W" -cp "$W/kashi_apkeditor.jar" com.reandroid.apkeditor.Main "$@" || _rc=$?
    fi
    return $_rc
}

kashi_patch_overlay() {   # <overlay apk on device>
    _name=$(basename "$1" .apk); _stock="$W/$_name.apk"; _src="$W/src_$_name"
    ui_print "- Patching $1"
    kashi_stock_copy "$1" "$_stock" || { ui_print "  ! stock overlay not reachable (reboot without the module and flash again)"; return 1; }
    [ -n "$DVM" ] || { ui_print "  ! ART runtime (dalvikvm) could not start"; return 1; }
    rm -rf "$_src"
    kashi_apkeditor d -i "$_stock" -o "$_src" > "$W/d_$_name.log" 2>&1
    kashi_ov_set "$_src" || { ui_print "  ! could not edit its strings"; return 1; }
    _out=$(kashi_modpath "$1"); mkdir -p "$(dirname "$_out")"
    kashi_apkeditor b -i "$_src" -o "$_out" > "$W/b_$_name.log" 2>&1
    if [ ! -s "$_out" ] || ! unzip -l "$_out" 2>/dev/null | grep -q resources.arsc; then
        tail -n 8 "$W/b_$_name.log" | while read -r l; do ui_print "  $l"; done
        rm -f "$_out"; return 1
    fi
    KASHI_CLEAN="$KASHI_CLEAN $_name"
    return 0
}

VA=/product/overlay/VoiceAssistAndroidOverlay/VoiceAssistAndroidOverlay.apk
HL=/product/overlay/MiuiHomeLauncherResOverlay.apk
OV_DONE=0
if [ -f "$VA" ]; then kashi_patch_overlay "$VA" && OV_DONE=1
elif [ -f "$HL" ]; then kashi_patch_overlay "$HL" && OV_DONE=1
fi
if [ "$OV_DONE" = 0 ]; then
    ui_print "- Adding KashiGoogleAssistOverlay"
    _d="$MODPATH/system/product/overlay/KashiGoogleAssistOverlay"
    mkdir -p "$_d"; cp -f "$W/KashiGoogleAssistOverlay.apk" "$_d/"
    KASHI_CLEAN="$KASHI_CLEAN KashiGoogleAssistOverlay"
fi

# Circle to Search feature flags (same file name as the ROM's, so it replaces it when present)
ui_print "- Adding Circle to Search features"
mkdir -p "$MODPATH/system/product/etc/permissions"
cp -f "$W/com.google.android.contextual_search.xml" "$MODPATH/system/product/etc/permissions/"

ui_print "- Setting permissions..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
# parsed-package cache + compiled code of what changed, nothing else
for d in $KASHI_CLEAN; do
    rm -rf /data/system/package_cache/*/"$d"-* 2>/dev/null
    rm -f /data/dalvik-cache/*/*@"$d"@* 2>/dev/null
done
rm -rf "$W"
ui_print "- Google becomes the default assistant after the reboot."
ui_print "- Done, reboot your device."

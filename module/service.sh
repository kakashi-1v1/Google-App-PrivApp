#!/system/bin/sh
# Makes Google the default assistant once (the user can still change it in Settings afterwards).
MODDIR=${0%/*}
# Mods Center: warn in the root manager if module files are not mounted
[ -f "$MODDIR/kashi_mount_check.sh" ] && ( . "$MODDIR/kashi_mount_check.sh"; kashi_boot_check ) &
PKG=com.google.android.googlequicksearchbox
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
sleep 10
[ -f "$MODDIR/.assistant_set" ] && exit 0
pm path "$PKG" >/dev/null 2>&1 || exit 0
cmd role add-role-holder android.app.role.ASSISTANT "$PKG" >/dev/null 2>&1 && touch "$MODDIR/.assistant_set"

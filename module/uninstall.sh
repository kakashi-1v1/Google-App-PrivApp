#!/system/bin/sh
# drop the parsed-package cache + compiled code of the Google app and the overlays, so the ROM's copies are re-read
for d in Velvet VoiceAssistAndroidOverlay MiuiHomeLauncherResOverlay KashiGoogleAssistOverlay; do
    rm -rf /data/system/package_cache/*/"$d"-* 2>/dev/null
    rm -f /data/dalvik-cache/*/*@"$d"@* 2>/dev/null
done

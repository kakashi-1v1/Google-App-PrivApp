# Google App PrivApp

Magisk / KernelSU / APatch module that installs the **latest Google app** (`com.google.android.googlequicksearchbox`) as a **privileged system app** and makes Google the **default assistant**, so Circle to Search and the other Google assistant features work.

Circle to Search, "Hey Google" and screen context only work when the Google app is a priv-app **and** the default assistant. On many HyperOS / MIUI ROMs (CN builds especially) the Google app is a normal app, or isn't on the system at all.

## Download

Get the zip from the [latest release](../../releases/latest):

| Zip | Size | What it does |
| --- | --- | --- |
| `…-online.zip` | ~5 MB | Downloads the newest Google app while flashing (progress is shown) |
| `…-offline-gapp<version>.zip` | ~270 MB | Ships the Google app that was newest when it was built; no internet needed. Update it later from the Play Store |

Flash it in the Magisk / KernelSU / APatch app and reboot. arm64, Android 11+.

## What it does

1. **Google app as priv-app**
   - If the ROM already has it as a priv-app, the module puts the new version in that same place.
   - If the ROM has it as a normal system app, that copy is hidden and the app is installed to `/product/priv-app/Velvet`.
   - Otherwise it's added to `/product/priv-app/Velvet`.
   - A privapp-permissions allowlist is installed with it.
   - Play Store updates keep working: the app is Google-signed and stays privileged when updated.
2. **Framework overlay**, which sets:
   - `config_defaultAssistant` to the Google app
   - `config_defaultContextualSearchPackageName` to the Google app (Circle to Search)
   - `config_defaultContentSuggestionsService` to Android System Intelligence

   Which overlay gets changed, in order:
   - `/product/overlay/VoiceAssistAndroidOverlay/VoiceAssistAndroidOverlay.apk` is patched if it exists.
   - Otherwise `/product/overlay/MiuiHomeLauncherResOverlay.apk` is patched.
   - Otherwise the module adds its own overlay (`KashiGoogleAssistOverlay`).

   Patching runs on the phone with APKEditor on the phone's own ART runtime, so no Java is bundled.
3. **Circle to Search features**: adds `com.google.android.feature.CONTEXTUAL_SEARCH` and `CONTEXTUAL_SEARCH_LIVE_TRANSLATE` (`/product/etc/permissions/com.google.android.contextual_search.xml`).
4. **Default assistant**: on the first boot after flashing, Google is given the assistant role. You can still change it in Settings.

## Where the Google app comes from

Every 6 hours the workflow in this repo:

1. Looks up the newest **stable** Google app on APKMirror (the `ve.arm64` nodpi APK, the same build ROMs ship).
2. Verifies it with `apksigner` and only accepts it if it is signed with **Google's certificate** for this app (SHA-256 `f0fd6c5b…db83`).
3. Publishes it as a `gapp-<version>` pre-release and records its SHA-256 in [`latest.json`](latest.json).

The online zip downloads that exact file and checks the SHA-256 before installing.

## Removing

Remove the module in your root manager and reboot. The ROM's own Google app and overlays come back.

---
Made by [🅺🅰🆂🅷🅸](https://t.me/kakashi1v1) · [t.me/kashis_cringey_stuffs](https://t.me/kashis_cringey_stuffs)

APKEditor (REAndroid, Apache-2.0) is bundled as `kashi_apkeditor.jar` (dex build). The Google app is © Google LLC.

#!/usr/bin/env bash
# make_privapp.sh <apk> <out xml>: privapp allowlist with every permission the app asks for
# (entries for non-privileged permissions are ignored by the system)
set -euo pipefail
{
  echo '<?xml version="1.0" encoding="utf-8"?>'
  echo '<permissions>'
  echo '    <privapp-permissions package="com.google.android.googlequicksearchbox">'
  aapt2 dump permissions "$1" 2>/dev/null | sed -nE "s/^uses-permission(-sdk-23)?: name='([^']+)'.*/        <permission name=\"\2\"\/>/p" | sort -u
  echo '    </privapp-permissions>'
  echo '</permissions>'
} > "$2"
grep -q '<permission name=' "$2" || { echo "no permissions parsed" >&2; exit 1; }

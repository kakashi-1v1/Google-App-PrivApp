# Sets the framework assistant strings in an overlay decoded with APKEditor (d, xml mode).
# kashi_ov_set <decoded dir>  -> 0 when strings.xml holds all three values (and public.xml has their ids)
KASHI_OV_GSA=com.google.android.googlequicksearchbox
KASHI_OV_ASI=com.google.android.as/com.google.android.apps.miphone.aiai.app.AiAiContentSuggestionsService

# next free id for a string: max string id + 1, or (max type id + 1) << 16 when the overlay has no strings yet
kashi_ov_next_id() {   # <public.xml>
    awk 'match($0, /id="0x[0-9a-fA-F]+"/) {
            id = substr($0, RSTART + 6, RLENGTH - 7); v = 0
            for (i = 1; i <= length(id); i++) v = v * 16 + index("0123456789abcdef", tolower(substr(id, i, 1))) - 1
            if (v < 2130706432) next                       # package id line (0x7f) or framework ids
            t = int(v / 65536) % 256; if (t > maxt) maxt = t; pkg = int(v / 16777216)
            if ($0 ~ /type="string"/) { if (v > maxs) maxs = v; st = 1 }
         }
         END { if (!pkg) pkg = 127; if (st) n = maxs + 1; else n = (pkg * 256 + maxt + 1) * 65536; printf "0x%08x\n", n }' "$1"
}

kashi_ov_set_one() {   # <values dir> <name> <value>
    _s="$1/strings.xml"; _p="$1/public.xml"
    if grep -q "name=\"$2\"" "$_s"; then
        sed -i "s|<string name=\"$2\"[^>]*>[^<]*</string>|<string name=\"$2\">$3</string>|; s|<string name=\"$2\"[^>]*/>|<string name=\"$2\">$3</string>|" "$_s"
    else
        sed -i "s|</resources>|  <string name=\"$2\">$3</string>\n</resources>|" "$_s"
    fi
    if [ -f "$_p" ] && ! grep -q "type=\"string\" name=\"$2\"" "$_p"; then
        _id=$(kashi_ov_next_id "$_p")
        sed -i "s|</resources>|  <public id=\"$_id\" type=\"string\" name=\"$2\" />\n</resources>|" "$_p"
    fi
    grep -q "<string name=\"$2\">$3</string>" "$_s"
}

kashi_ov_set() {
    _v=$(ls -d "$1"/resources/package_*/res/values 2>/dev/null | head -n1)
    [ -n "$_v" ] || return 1
    [ -f "$_v/strings.xml" ] || printf '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n</resources>\n' > "$_v/strings.xml"
    kashi_ov_set_one "$_v" config_defaultAssistant "$KASHI_OV_GSA" &&
    kashi_ov_set_one "$_v" config_defaultContentSuggestionsService "$KASHI_OV_ASI" &&
    kashi_ov_set_one "$_v" config_defaultContextualSearchPackageName "$KASHI_OV_GSA"
}

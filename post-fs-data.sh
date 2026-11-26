#!/system/bin/sh
# Built from the live ROM files at every boot (so OTA changes are kept), then
# bind-mounted over the originals:
#  - app_v2.xml (my_stock + my_region): drop the lines that disable ColorOS
#    Contacts / InCallUI / Mms
#  - my_region app-features: add the "ColorOS dialer" flags when the ROM lacks them
#    (IN has them; OnePlus Open EU/global does not)
MODDIR=${0%/*}
LOG=$MODDIR/post-fs-data.log
FEATURES="com.android.phone.oplus_dialer_enable com.android.server.telecom.oplus_dialer_enable"

# $1 = ROM file, $2 = patched copy, $3 = tag that must still close the copy
mount_patched() {
  if ! grep -q "$3" "$2"; then
    rm -f "$2"
    echo "$1: generated file looks wrong - not mounted"
    return 1
  fi
  if cmp -s "$1" "$2"; then
    rm -f "$2"
    echo "$1: nothing to change"
    return 0
  fi
  chmod 0644 "$2"
  ctx=$(ls -Z "$1" | awk '{print $1}')
  [ -n "$ctx" ] && chcon "$ctx" "$2"
  if mount --bind "$2" "$1"; then
    echo "$1: patched copy mounted (context $ctx)"
  else
    echo "$1: bind mount FAILED"
  fi
}

{
  echo "== $(date) post-fs-data"

  n=0
  for part in my_stock my_region; do
    src=/$part/etc/config/app_v2.xml
    [ -f "$src" ] || continue
    n=$((n + 1))
    sed -e '/pkg="com\.android\.contacts"/d' \
        -e '/pkg="com\.android\.incallui"/d' \
        -e '/pkg="com\.android\.mms"/d' "$src" > "$MODDIR/app_v2.$part.xml"
    mount_patched "$src" "$MODDIR/app_v2.$part.xml" '</app>'
  done
  [ "$n" = 0 ] && echo "no app_v2.xml found - is this ColorOS?"

  src=/my_region/etc/extension/com.oplus.app-features.xml
  if [ -f "$src" ]; then
    out=$MODDIR/app-features.xml
    cp "$src" "$out"
    for f in $FEATURES; do
      grep -q "name=\"$f\"" "$out" && continue
      sed -i "s|</extend_features>|$(printf '\t')<app_feature name=\"$f\"/>\n</extend_features>|" "$out"
      echo "adding app feature $f"
    done
    mount_patched "$src" "$out" '</extend_features>'
  fi
} >> "$LOG" 2>&1

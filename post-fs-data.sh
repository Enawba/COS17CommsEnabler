#!/system/bin/sh
# Re-create the stock app_v2.xml without the lines that disable the ColorOS
# Contacts / InCallUI / Mms apps and bind-mount it over the original file.
# Built from the live stock file every boot, so OTA changes to it are kept.
MODDIR=${0%/*}
STOCK=/my_stock/etc/config/app_v2.xml
OUT=$MODDIR/app_v2.xml
LOG=$MODDIR/post-fs-data.log

{
  echo "== $(date) post-fs-data"
  if [ ! -f "$STOCK" ]; then
    echo "stock $STOCK missing - nothing to do"
    exit 0
  fi
  sed -e '/pkg="com\.android\.contacts"/d' \
      -e '/pkg="com\.android\.incallui"/d' \
      -e '/pkg="com\.android\.mms"/d' "$STOCK" > "$OUT.tmp"
  if grep -q '</app>' "$OUT.tmp"; then
    mv -f "$OUT.tmp" "$OUT"
    chmod 0644 "$OUT"
    CTX=$(ls -Z "$STOCK" | awk '{print $1}')
    [ -n "$CTX" ] && chcon "$CTX" "$OUT"
    if mount --bind "$OUT" "$STOCK"; then
      echo "patched app_v2.xml mounted (context $CTX)"
    else
      echo "bind mount FAILED"
    fi
  else
    rm -f "$OUT.tmp"
    echo "generated file looks wrong - not mounted"
  fi
} >> "$LOG" 2>&1

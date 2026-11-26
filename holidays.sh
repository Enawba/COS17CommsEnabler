# Sourced by service.sh and action.sh (needs MODDIR and CONF).
#
# The ColorOS Calendar stores the public holidays of the region chosen in
# Calendar > Settings > Holidays in shared_prefs/calendar_legal_holiday.xml, as
# Google's "Holidays in <country>" list, often in the local language (India: Hindi).
# holidays_import replaces that list with Google's ENGLISH list for the same region,
# bundled in $MODDIR/holidays/<CC>. OPPO's version number is kept, so the Calendar
# still notices real updates; a new download is replaced again at the next run.

CALENDARS="com.oplus.calendar com.coloros.calendar"

# $1 = pref file, $2 = region data file, $3 = output; returns 1 if the format is unknown
holidays_build() {
  n=$(grep -n 'name="calendar_country_holiday_content"' "$1" | head -n 1 | cut -d: -f1)
  [ -n "$n" ] || return 1
  ver=$(sed -n "${n}s/.*name=\"calendar_country_holiday_content\">{&quot;version&quot;:&quot;\([^&]*\)&quot;,&quot;data&quot;:.*/\1/p" "$1")
  [ -n "$ver" ] || return 1
  indent=$(sed -n "${n}s/<string .*//p" "$1")
  {
    [ "$n" -gt 1 ] && head -n $((n - 1)) "$1"
    printf '%s<string name="calendar_country_holiday_content">{&quot;version&quot;:&quot;%s&quot;,&quot;data&quot;:' "$indent" "$ver"
    cat "$2"
    printf '}</string>\n'
    tail -n +$((n + 1)) "$1"
  } > "$3"
}

# $1 = boot   : at boot, closes a running Calendar if needed (skipped if turned off)
#      timer  : periodic check, leaves a running Calendar alone (skipped if turned off)
#      action : Action button, always runs and reports everything
holidays_import() {
  mode=$1
  if [ "$mode" != action ] && grep -q '^TRANSLATE_HOLIDAYS=0' "$CONF" 2>/dev/null; then
    return 0
  fi
  found=0
  for pkg in $CALENDARS; do
    pref=${APPDATA:-/data/data}/$pkg/shared_prefs/calendar_legal_holiday.xml
    if [ ! -f "$pref" ]; then
      if [ "$mode" = action ] && [ -d "${APPDATA:-/data/data}/$pkg" ]; then
        found=1
        echo "$pkg: no holidays downloaded yet."
        echo "  Open Calendar > Settings > Holidays, pick your region, then run this again."
      fi
      continue
    fi
    found=1
    cc=$(sed -n 's/.*name="sp_key_calendar_holiday_country_code">\([A-Za-z]*\)<.*/\1/p' "$pref" |
         head -n 1 | tr 'a-z' 'A-Z')
    if [ -z "$cc" ]; then
      [ "$mode" = timer ] || echo "$pkg: no holiday region selected in Calendar settings"
      continue
    fi
    data=$MODDIR/holidays/$cc
    if [ ! -f "$data" ]; then
      [ "$mode" = timer ] || echo "$pkg: no English holiday list for region $cc - left as it is"
      continue
    fi
    tmp=$MODDIR/holidays.tmp
    if ! holidays_build "$pref" "$data" "$tmp"; then
      rm -f "$tmp"
      [ "$mode" = timer ] || echo "$pkg: unknown holiday data format - left as it is"
      continue
    fi
    if cmp -s "$pref" "$tmp"; then
      rm -f "$tmp"
      [ "$mode" = action ] && echo "$pkg: holidays for $cc are already in English"
      continue
    fi
    if pidof "$pkg" >/dev/null 2>&1; then
      if [ "$mode" = timer ]; then
        rm -f "$tmp"
        continue
      fi
      am force-stop "$pkg"
      # the app may have written the file while closing: build again from the latest
      holidays_build "$pref" "$data" "$tmp" || { rm -f "$tmp"; continue; }
    fi
    cp "$pref" "$MODDIR/holidays_original_$pkg.xml"
    cat "$tmp" > "$pref" && rm -f "$pref.bak"     # cat keeps owner + SELinux label
    rm -f "$tmp"
    echo "$(date '+%F %T') $pkg: holidays for $cc replaced with the English list"
  done
  if [ "$mode" = action ] && [ "$found" = 0 ]; then
    echo "ColorOS Calendar is not installed (com.oplus.calendar / com.coloros.calendar)."
  fi
  return 0
}

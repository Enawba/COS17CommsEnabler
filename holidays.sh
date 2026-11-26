# Sourced by service.sh and action.sh (needs MODDIR and CONF).
#
# The ColorOS Calendar stores the public holidays of the region chosen in
# Calendar > Settings > Holidays in shared_prefs/calendar_legal_holiday.xml, as
# Google's "Holidays in <country>" list, often in the local language (India: Hindi).
# holidays_import replaces that list with Google's ENGLISH list for the same region,
# bundled in $MODDIR/holidays/<CC>. OPPO's version number is kept, so the Calendar
# still notices real updates; a new download is replaced again at the next run.
#
# Note: the holiday line is ~100 KB. Busybox regex on such a line (".*foo") can take
# minutes, so only a short prefix of it is ever matched.

CALENDARS="com.oplus.calendar com.coloros.calendar"
KEY=calendar_country_holiday_content

# verbose output (Action button only)
say() { [ "$mode" = action ] && echo "  $*"; return 0; }

# $1 = pref file, $2 = region data file, $3 = output; returns 1 if the format is unknown
holidays_build() {
  n=$(grep -n "name=\"$KEY\"" "$1" | head -n 1 | cut -d: -f1)
  [ -n "$n" ] || { say "no '$KEY' entry in the file"; return 1; }
  head=$(sed -n "${n}{p;q}" "$1" | cut -c1-200)
  ver=$(echo "$head" | sed -n "s/.*name=\"$KEY\">{&quot;version&quot;:&quot;\([^&]*\)&quot;,&quot;data&quot;:.*/\1/p")
  [ -n "$ver" ] || { say "unexpected start of the holiday entry: $(echo "$head" | cut -c1-120)"; return 1; }
  indent=$(echo "$head" | sed -n 's/<string .*//p')
  {
    [ "$n" -gt 1 ] && head -n $((n - 1)) "$1"
    printf '%s<string name="%s">{&quot;version&quot;:&quot;%s&quot;,&quot;data&quot;:' "$indent" "$KEY" "$ver"
    cat "$2"
    printf '}</string>\n'
    tail -n +$((n + 1)) "$1"
  } > "$3"
}

# $1 = boot   : at boot, closes a running Calendar if needed (skipped if turned off)
#      timer  : periodic check, leaves a running Calendar alone (skipped if turned off)
#      action : Action button, always runs and explains every step
holidays_import() {
  mode=$1
  if [ "$mode" != action ] && grep -q '^TRANSLATE_HOLIDAYS=0' "$CONF" 2>/dev/null; then
    return 0
  fi
  found=0
  for pkg in $CALENDARS; do
    dir=${APPDATA:-/data/data}/$pkg
    pref=$dir/shared_prefs/calendar_legal_holiday.xml
    if [ ! -d "$dir" ]; then
      say "$pkg: not installed"
      continue
    fi
    found=1
    [ "$mode" = action ] && echo "$pkg:"
    if [ ! -f "$pref" ]; then
      [ "$mode" = action ] && echo "  no holidays downloaded yet. Open Calendar > Settings > Holidays," &&
        echo "  pick your region, then press Action again."
      continue
    fi
    say "holiday file: $pref ($(wc -c < "$pref") bytes)"
    cc=$(grep -o 'name="sp_key_calendar_holiday_country_code">[A-Za-z]*<' "$pref" | head -n 1 |
         sed 's/.*">//; s/<//' | tr 'a-z' 'A-Z')
    if [ -z "$cc" ]; then
      [ "$mode" = timer ] || echo "  $pkg: no holiday region selected in Calendar settings"
      continue
    fi
    say "region selected in Calendar: $cc"
    data=$MODDIR/holidays/$cc
    if [ ! -f "$data" ]; then
      [ "$mode" = timer ] || echo "  $pkg: no English holiday list for region $cc - left as it is"
      continue
    fi
    say "English list: $data ($(grep -o '&quot;summary&quot;' "$data" | wc -l) holidays)"
    tmp=$MODDIR/holidays.tmp
    if ! holidays_build "$pref" "$data" "$tmp"; then
      rm -f "$tmp"
      [ "$mode" = timer ] || echo "  $pkg: unknown holiday data format - left as it is"
      continue
    fi
    say "OPPO list version: $ver (kept)"
    if cmp -s "$pref" "$tmp"; then
      rm -f "$tmp"
      [ "$mode" = action ] && echo "  holidays for $cc are already in English - nothing to do"
      continue
    fi
    say "current list differs from the English one -> replacing"
    if pidof "$pkg" >/dev/null 2>&1; then
      if [ "$mode" = timer ]; then
        rm -f "$tmp"
        continue
      fi
      say "Calendar is running -> closing it"
      am force-stop "$pkg"
      # the app may have written the file while closing: build again from the latest
      holidays_build "$pref" "$data" "$tmp" || { rm -f "$tmp"; continue; }
    else
      say "Calendar is not running"
    fi
    cp "$pref" "$MODDIR/holidays_original_$pkg.xml"
    say "backup of the old list: $MODDIR/holidays_original_$pkg.xml"
    cat "$tmp" > "$pref" && rm -f "$pref.bak"     # cat keeps owner + SELinux label
    if cmp -s "$pref" "$tmp"; then
      say "written and verified ($(wc -c < "$pref") bytes, owner/SELinux label kept)"
      echo "$(date '+%F %T') $pkg: holidays for $cc replaced with the English list"
    else
      echo "  $pkg: writing the holiday file FAILED"
    fi
    rm -f "$tmp"
  done
  if [ "$mode" = action ] && [ "$found" = 0 ]; then
    echo "ColorOS Calendar is not installed (com.oplus.calendar / com.coloros.calendar)."
  fi
  return 0
}

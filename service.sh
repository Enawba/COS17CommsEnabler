#!/system/bin/sh
MODDIR=${0%/*}
LOG=$MODDIR/service.log
CONF=/data/adb/cos17comms.conf
FLAG=/data/adb/cos17comms.google_disabled
APK=$MODDIR/apk/Calendar.apk
CAL=com.oplus.calendar
CAL_VER=17006030
HOLIDAY_CHECK=21600   # seconds between holiday checks after boot (6 h)
. "$MODDIR/holidays.sh"

installed() { pm list packages "$1" 2>/dev/null | grep -q "^package:$1\$"; }

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
sleep 15

{
  echo "== $(date) service"

  # 1) make sure the ColorOS comms apps that this ROM has are enabled for the owner user
  #    (OnePlus Open EU/global firmware has no ColorOS Messages - that is skipped)
  for p in com.android.contacts com.android.incallui com.android.mms; do
    pm install-existing --user 0 "$p" >/dev/null 2>&1
    if installed "$p"; then
      pm enable --user 0 "$p"
    else
      echo "$p is not on this ROM - skipped"
    fi
  done

  # 2) ColorOS (global) Calendar, only in the all-in-one zip: install if missing or older
  have=$(dumpsys package "$CAL" 2>/dev/null | grep -m1 'versionCode=' | sed 's/.*versionCode=\([0-9]*\).*/\1/')
  if [ -f "$APK" ] && { [ -z "$have" ] || [ "$have" -lt "$CAL_VER" ]; }; then
    echo "installing $CAL (installed: ${have:-none})"
    SIZE=$(stat -c %s "$APK")
    cat "$APK" | pm install -r -g -S "$SIZE"
  elif [ -f "$APK" ]; then
    echo "$CAL already at ${have}"
  fi

  # 3) once per app: make ColorOS Phone / Messages the default apps
  #    (.roles_done = both done by v1.0-v1.4)
  [ -f "$MODDIR/.roles_done" ] && touch "$MODDIR/.dialer_done" "$MODDIR/.sms_done"
  if [ ! -f "$MODDIR/.dialer_done" ] && installed com.android.contacts; then
    cmd role add-role-holder --user 0 android.app.role.DIALER com.android.contacts 0 &&
      touch "$MODDIR/.dialer_done"
  fi
  if [ ! -f "$MODDIR/.sms_done" ] && installed com.android.mms; then
    cmd role add-role-holder --user 0 android.app.role.SMS com.android.mms 0 &&
      touch "$MODDIR/.sms_done"
  fi
  # safety net: a default app that vanished (e.g. the Messages add-on was removed)
  # -> give the role back to the Google app, so calls / SMS keep working
  for pair in "DIALER:com.google.android.dialer:.dialer_done" \
              "SMS:com.google.android.apps.messaging:.sms_done"; do
    role=android.app.role.${pair%%:*}; rest=${pair#*:}; gapp=${rest%%:*}; done_flag=${rest#*:}
    [ -n "$(cmd role get-role-holders --user 0 "$role")" ] && continue
    installed "$gapp" || continue
    pm enable --user 0 "$gapp"
    cmd role add-role-holder --user 0 "$role" "$gapp" 0
    rm -f "$MODDIR/$done_flag"     # ColorOS app comes back later -> make it default again
    echo "no default app for $role -> $gapp"
  done

  DIALER=$(cmd role get-role-holders --user 0 android.app.role.DIALER)
  SMS=$(cmd role get-role-holders --user 0 android.app.role.SMS)
  echo "default dialer: $DIALER / default sms: $SMS"

  # 4) optional: disable Google Dialer / Google Messages
  #    Safety: each Google app is only disabled while its ColorOS replacement is the
  #    default app, so calls and SMS keep working (no ColorOS Messages = Google Messages stays).
  DISABLE_GOOGLE=0
  [ -f "$CONF" ] && grep -q '^DISABLE_GOOGLE=1' "$CONF" && DISABLE_GOOGLE=1
  for pair in "com.google.android.dialer:$DIALER:com.android.contacts" \
              "com.google.android.apps.messaging:$SMS:com.android.mms"; do
    gapp=${pair%%:*}; rest=${pair#*:}; holder=${rest%%:*}; ours=${rest#*:}
    installed "$gapp" || continue
    if [ "$DISABLE_GOOGLE" = 1 ] && [ "$holder" = "$ours" ]; then
      pm disable-user --user 0 "$gapp"
      touch "$FLAG"
    elif [ "$DISABLE_GOOGLE" = 1 ]; then
      echo "NOT disabling $gapp: $ours is not the default app"
      [ -f "$FLAG" ] && pm enable --user 0 "$gapp"
    elif [ -f "$FLAG" ]; then
      pm enable --user 0 "$gapp"     # option switched off -> give the Google app back
    fi
  done
  [ "$DISABLE_GOOGLE" = 1 ] || rm -f "$FLAG"

  # 5) Calendar holidays: English list for the selected region (holidays.sh)
  holidays_import boot
} >> "$LOG" 2>&1

# keep checking: a Calendar that downloads a new list later is fixed while it is closed
while sleep "$HOLIDAY_CHECK"; do
  holidays_import timer >> "$LOG" 2>&1
done &

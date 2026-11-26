#!/system/bin/sh
MODDIR=${0%/*}
LOG=$MODDIR/service.log
CONF=/data/adb/cos17comms.conf
FLAG=/data/adb/cos17comms.google_disabled
APK=$MODDIR/apk/Calendar.apk
CAL=com.oplus.calendar
CAL_VER=17006030
GOOGLE_APPS="com.google.android.dialer com.google.android.apps.messaging"

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
sleep 15

{
  echo "== $(date) service"

  # 1) make sure the ColorOS comms apps are enabled for the owner user
  for p in com.android.contacts com.android.incallui com.android.mms; do
    pm install-existing --user 0 "$p" >/dev/null 2>&1
    pm enable --user 0 "$p"
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

  # 3) one-time: make ColorOS Phone / Messages the default apps
  if [ ! -f "$MODDIR/.roles_done" ]; then
    cmd role add-role-holder --user 0 android.app.role.DIALER com.android.contacts 0 && \
    cmd role add-role-holder --user 0 android.app.role.SMS com.android.mms 0 && \
    touch "$MODDIR/.roles_done"
  fi
  DIALER=$(cmd role get-role-holders --user 0 android.app.role.DIALER)
  SMS=$(cmd role get-role-holders --user 0 android.app.role.SMS)
  echo "default dialer: $DIALER / default sms: $SMS"

  # 4) optional: disable Google Dialer + Google Messages
  DISABLE_GOOGLE=0
  [ -f "$CONF" ] && grep -q '^DISABLE_GOOGLE=1' "$CONF" && DISABLE_GOOGLE=1
  if [ "$DISABLE_GOOGLE" = 1 ]; then
    # Safety: only when ColorOS apps really are the defaults, so calls/SMS keep working.
    if [ "$DIALER" = "com.android.contacts" ] && [ "$SMS" = "com.android.mms" ]; then
      for p in $GOOGLE_APPS; do
        pm list packages "$p" | grep -q "^package:$p\$" || continue
        pm disable-user --user 0 "$p"
      done
      touch "$FLAG"
    else
      echo "NOT disabling Google apps: ColorOS Phone/Messages are not the default apps"
    fi
  elif [ -f "$FLAG" ]; then
    # option switched off -> give the Google apps back
    for p in $GOOGLE_APPS; do pm enable --user 0 "$p"; done
    rm -f "$FLAG"
  fi
} >> "$LOG" 2>&1

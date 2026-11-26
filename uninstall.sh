#!/system/bin/sh
# Restore Google Dialer + Messages and hand the default roles back to them,
# so calls/SMS keep working after the module is removed.
# (ColorOS Calendar is left installed - uninstall it from Settings if unwanted.)
for p in com.google.android.dialer com.google.android.apps.messaging; do
  pm enable --user 0 "$p"
done
cmd role add-role-holder --user 0 android.app.role.DIALER com.google.android.dialer 0
cmd role add-role-holder --user 0 android.app.role.SMS com.google.android.apps.messaging 0
rm -f /data/adb/cos17comms.conf /data/adb/cos17comms.google_disabled

SKIPUNZIP=0
CONF=/data/adb/cos17comms.conf

ui_print " "
ui_print "  COS17 Comms Enabler  by enawba"
ui_print "  ColorOS Contacts + Phone + Messages + English holidays"
ui_print " "

STOCK=/my_stock/etc/config/app_v2.xml
[ -f "$STOCK" ] || abort "! $STOCK not found - this module is for ColorOS 16/17 only"

ui_print "- Device: $(getprop ro.product.model) / $(getprop ro.build.display.id)"
for p in Contacts InCallUI Mms; do
  if [ -d /my_stock/priv-app/$p ]; then
    ui_print "- found ColorOS $p"
  elif [ "$p" = Mms ]; then
    ui_print "- ColorOS Messages is not on this ROM (e.g. OnePlus Open EU):"
    ui_print "  Google Messages stays the SMS app"
  else
    ui_print "! ColorOS $p is missing on this ROM - it cannot be enabled"
  fi
done
if grep -qE 'pkg="com\.android\.(contacts|incallui|mms)"' "$STOCK" /my_region/etc/config/app_v2.xml 2>/dev/null; then
  ui_print "- app_v2.xml disables ColorOS comms apps -> patched at boot"
else
  ui_print "- app_v2.xml does not disable them (nothing to patch)"
fi
FEAT=/my_region/etc/extension/com.oplus.app-features.xml
if [ -f "$FEAT" ] && ! grep -q 'name="com.android.server.telecom.oplus_dialer_enable"' "$FEAT"; then
  ui_print "- ROM lacks the ColorOS dialer flags -> added at boot"
fi
if [ -f "$MODPATH/apk/Calendar.apk" ]; then
  ui_print "- bundled ColorOS Calendar will be installed after reboot"
elif pm list packages 2>/dev/null | grep -qE '^package:com\.(oplus|coloros)\.calendar$'; then
  ui_print "- ColorOS Calendar is already installed"
else
  ui_print "- ColorOS Calendar is not part of this zip:"
  ui_print "  install the Calendar APK from the GitHub release page"
fi

# ---- option: disable Google Dialer + Google Messages ---------------------------
# Returns 0 = Vol+, 1 = Vol-, 2 = no key within ~10 s
vol_key() {
  i=0
  while [ $i -lt 10 ]; do
    ev=$(timeout 1 getevent -lqc 1 2>/dev/null | grep -E 'KEY_VOLUME(UP|DOWN) +DOWN')
    case "$ev" in
      *KEY_VOLUMEUP*) return 0 ;;
      *KEY_VOLUMEDOWN*) return 1 ;;
    esac
    i=$((i + 1))
  done
  return 2
}

OLD=0
[ -f "$CONF" ] && grep -q '^DISABLE_GOOGLE=1' "$CONF" && OLD=1
TRANSLATE=1
[ -f "$CONF" ] && grep -q '^TRANSLATE_HOLIDAYS=0' "$CONF" && TRANSLATE=0
ui_print " "
ui_print "- Disable Google Dialer + Google Messages?"
ui_print "    Vol+ = YES, disable them"
ui_print "    Vol- = NO, keep them"
ui_print "  (no key in 10 s keeps: $( [ $OLD = 1 ] && echo YES || echo NO ))"
vol_key
case $? in
  0) CHOICE=1 ;;
  1) CHOICE=0 ;;
  *) CHOICE=$OLD ;;
esac
{ echo "DISABLE_GOOGLE=$CHOICE"; echo "TRANSLATE_HOLIDAYS=$TRANSLATE"; } > "$CONF"
chmod 0600 "$CONF"
if [ "$CHOICE" = 1 ]; then
  ui_print "- Google Dialer + Messages WILL be disabled after reboot"
  ui_print "  (only once ColorOS Phone/Messages are the default apps)"
else
  ui_print "- Google Dialer + Messages will be kept"
fi
ui_print "  Change later: edit $CONF (DISABLE_GOOGLE=0/1) and reboot"
ui_print " "
if [ "$TRANSLATE" = 1 ]; then
  ui_print "- Calendar holidays: English list for your region"
  ui_print "  (at boot, every 6 h and with the module's Action button;"
  ui_print "   TRANSLATE_HOLIDAYS=0 in $CONF turns the automatic part off)"
else
  ui_print "- Automatic English holidays are OFF (TRANSLATE_HOLIDAYS=0)"
  ui_print "  The module's Action button still does it on demand"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
ui_print " "
ui_print "- Reboot to apply. Logs: $MODPATH/*.log"

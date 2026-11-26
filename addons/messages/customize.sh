SKIPUNZIP=0

ui_print " "
ui_print "  COS17 Messages add-on  by enawba"
ui_print "  ColorOS Messages for ROMs that don't ship it"
ui_print " "

[ -f /my_stock/etc/config/app_v2.xml ] || abort "! This add-on is for ColorOS 17 only"
[ "$ARCH" = arm64 ] || abort "! arm64 devices only (this is $ARCH)"
[ "$(getprop ro.build.version.sdk)" -ge 31 ] || abort "! Android 12 or newer needed"
if [ -d /my_stock/priv-app/Mms ]; then
  abort "! This ROM already has ColorOS Messages - you don't need this add-on.
  COS17 Comms Enabler enables the built-in one."
fi
ui_print "- Device: $(getprop ro.product.model) / $(getprop ro.build.display.id)"
ui_print "- ColorOS Messages is not on this ROM -> added as a system app"

MAIN=COS17CommsEnabler
if [ -d /data/adb/modules/$MAIN ] || [ -d /data/adb/modules_update/$MAIN ]; then
  ui_print "- COS17 Comms Enabler found: it enables Messages and makes it"
  ui_print "  the default SMS app on the first boot"
else
  ui_print " "
  ui_print "! COS17 Comms Enabler is NOT installed. Install it too:"
  ui_print "  without it, the ROM keeps ColorOS Messages switched off."
fi

set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
ui_print " "
ui_print "- Reboot to apply. The first boot takes a little longer."

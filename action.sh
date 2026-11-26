#!/system/bin/sh
# "Action" button in KernelSU / KernelSU-Next / Magisk (28+):
# replace the Calendar's holidays with the English list for its region, right now,
# and show every step.
MODDIR=$(cd "${0%/*}" && pwd)
CONF=/data/adb/cos17comms.conf
. "$MODDIR/holidays.sh"

start=$(date +%s)
echo "COS17 Comms Enabler $(grep '^version=' "$MODDIR/module.prop" | cut -d= -f2) - English holidays"
echo "$(getprop ro.product.model) / $(getprop ro.build.display.id)"
echo "settings: $(tr '\n' ' ' < "$CONF" 2>/dev/null)"
echo "bundled regions: $(ls "$MODDIR/holidays" | wc -l)"
echo " "
holidays_import action 2>&1 | tee -a "$MODDIR/service.log"
echo " "
echo "Done in $(( $(date +%s) - start )) s. Open Calendar to see the holidays."

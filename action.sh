#!/system/bin/sh
# "Action" button in KernelSU / KernelSU-Next / Magisk (28+):
# replace the Calendar's holidays with the English list for its region, right now.
MODDIR=${0%/*}
CONF=/data/adb/cos17comms.conf
. "$MODDIR/holidays.sh"

echo "COS17 Comms Enabler - English holidays"
echo " "
holidays_import action | tee -a "$MODDIR/service.log"
echo " "
echo "Done. Open Calendar to see the holidays."

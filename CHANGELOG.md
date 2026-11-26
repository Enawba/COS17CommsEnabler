# Changelog

## v1.7 (2026-11-27)

**Fixes, all tested on a OnePlus 12 (CPH2573, ColorOS 17, KernelSU-Next)**
- **Boot steps never ran:** enabling the apps, setting the default dialer/SMS app and
  disabling the Google apps all failed with `cmd: Failure calling service …: Failed
  transaction`. The boot script sent their output straight into its log file under
  `/data/adb`, which Android's system services may not write to. The output now goes
  through a pipe, and all of these steps work. This affected every earlier version.
- **Action button hung:** it showed only its title and never finished. Reading OPPO's
  version number ran a regex over the ~100 KB holiday line, which takes minutes with
  busybox. Only a short prefix is matched now; the Action button finishes in under a
  second, and the boot step and 6-hour check are fast too.

**Verbose Action log**
- The Action button now shows every step:
  - module version, device, ROM and settings
  - the holiday file and the region selected in the Calendar
  - the English list used and OPPO's version number (kept)
  - whether the Calendar was running and was closed
  - the backup location, the write and its verification, and the time taken
- Each run is also appended to `service.log`.

## v1.6 + Messages add-on v1.0 (2026-11-27)

**New: COS17 Messages add-on (`COS17MessagesAddon_v1.0.zip`)**
- Adds ColorOS Messages (`com.android.mms` 17.62.60, from ColorOS 17 India, unmodified)
  as a system app on firmware that doesn't ship it, such as the OnePlus Open EU/global
  build.
- It goes in `/system/priv-app/COS17Mms` with its native libraries unpacked, plus a
  `privapp-permissions` file with the same 21 privileged permissions as on the India
  firmware.
- It refuses to install where ColorOS Messages already exists.
- It needs COS17 Comms Enabler v1.6+.
- Not yet tested on a real OnePlus Open.

**COS17 Comms Enabler v1.6**
- Safety net: if a default dialer or SMS app disappears (for example after removing the
  add-on), the next boot gives the role back to the Google app and re-enables it if
  needed.
- The installer recognises the Messages add-on and points to it on firmware without
  ColorOS Messages.

## v1.5 (2026-11-27)

**English public holidays for your region**
- The module no longer translates Hindi word by word. It now replaces the Calendar's
  holiday list with Google's English list for the region selected in
  Calendar → Settings → Holidays.
- English lists for 70 regions (2025–2031) are bundled in the module, so the phone needs
  no internet access for this.
- OPPO's version number is kept, so the Calendar still downloads real updates; the next
  run replaces them with English again.
- For an unknown region or an unexpected file format, the list is left as it is and a
  note goes into `service.log`.

**Action button**
- `action.sh` applies the English holidays right away from the KernelSU / KernelSU-Next /
  Magisk manager. It also works when `TRANSLATE_HOLIDAYS=0`.

**OnePlus Open EU and other non-India ColorOS 17 firmware**
- `post-fs-data.sh` patches `app_v2.xml` in both `my_stock` and `my_region`.
- It also adds the ColorOS-dialer feature flags
  (`com.android.phone.oplus_dialer_enable` and
  `com.android.server.telecom.oplus_dialer_enable`) on firmware that lacks them.
- Apps the firmware doesn't have are skipped. The OnePlus Open EU firmware has no ColorOS
  Messages, so Google Messages stays the SMS app there.
- The default dialer and default SMS app are now set independently. Before, a missing
  Messages app made the module reset the default dialer at every boot.
- Each Google app is now disabled only while its own ColorOS replacement is the default.

**Tools**
- `tools/holidays.py` replaces `tools/calendar_holidays_en.py`:
  - `apply` puts a fresh English list on a phone over adb (`--country`, `--package`,
    `--dry-run`).
  - `update` refreshes the bundled lists.

**Testing**
- Tested on a PC with the real India holiday file and the real IN and EU firmware files.
- Not yet run on a phone (busybox) and not tested on a OnePlus Open.

## v1.4 (2026-11-26)
- The Calendar's Hindi "Holidays in India" list is translated to English at boot and
  every 6 hours (while the Calendar is closed).
- Option `TRANSLATE_HOLIDAYS=0/1` in `/data/adb/cos17comms.conf`.

## v1.3 (2026-11-26)
- The Calendar on the release page is now the global ColorOS Calendar
  (`com.oplus.calendar` 17.6.30, English, Indian holidays, Panchang) instead of the China
  one.
- The installer recognises either Calendar.

## v1.2 (2026-11-26)
- The ColorOS Calendar is a separate APK on the release page, so the module zip is about
  5 KB instead of 86 MB.
- `build.py --with-calendar` still builds an all-in-one zip.
- Added the MIT license.
- Added `tools/calendar_holidays_en.py`: translates the Hindi India holidays from a PC.

## v1.1 (2026-11-26)
- Option (volume keys at install) to disable Google Dialer + Google Messages, only while
  ColorOS Phone / Messages are the default apps.
- `uninstall.sh` restores the Google apps as defaults.

## v1.0 (2026-11-26)
- Enables ColorOS Contacts, Phone (InCallUI) and Messages on ColorOS 17 India by patching
  `my_stock/etc/config/app_v2.xml` at boot.
- Makes them the default dialer / SMS app once.
- Installs the ColorOS dynamic Calendar (China build) bundled in the zip.

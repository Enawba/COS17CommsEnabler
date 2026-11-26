# COS17 Comms Enabler

A KernelSU / Magisk module for **ColorOS 17 (India / global builds)**. It brings back the
stock ColorOS communication apps in place of the Google ones:

- **ColorOS Contacts + Phone (new UI)**: `com.android.contacts` and `com.android.incallui`
- **ColorOS Messages**: `com.android.mms`
- *Optional:* disables **Google Dialer** and **Google Messages**
- **ColorOS dynamic Calendar** (`com.oplus.calendar` 17.6.30, the global build) is a
  **separate APK** on the release page. It is not part of the module zip.

Tested target: OnePlus 12 (CPH2573, India) on ColorOS 17 with KernelSU-Next.

## How it works

The Indian/global ColorOS 17 firmware already ships ColorOS Contacts, InCallUI and Messages
in `/my_stock/priv-app`, at the same versions as the China build. They are only switched off
by three lines in `/my_stock/etc/config/app_v2.xml`:

```xml
<disable pkg="com.android.contacts" priority="10"/>
<disable pkg="com.android.incallui" priority="10"/>
<disable pkg="com.android.mms" priority="10"/>
```

| Step | Script | What happens |
|---|---|---|
| Boot (early) | `post-fs-data.sh` | Reads the device's **own** stock `app_v2.xml`, removes only those three lines and bind-mounts the result over the original file. It is rebuilt every boot, so future OTA changes to that file are kept. |
| Boot completed | `service.sh` | Re-enables the three apps if an earlier boot disabled them. |
| First boot only | `service.sh` | Makes ColorOS Phone the default dialer and ColorOS Messages the default SMS app. You can change defaults freely afterwards. |
| Optional | `service.sh` | Disables Google Dialer + Google Messages (see below). |
| Module removed | `uninstall.sh` | Re-enables the Google apps and makes them the default dialer / SMS app again. |

No China-only features are enabled (China Mobile video calling, Chinese number tagging and
similar), because they make no sense with non-Chinese SIM cards.

## Install

1. Download `COS17CommsEnabler_<version>.zip` from [Releases](../../releases).
2. Flash it in the KernelSU / KernelSU-Next / Magisk manager.
3. When asked **"Disable Google Dialer + Google Messages?"**:
   - **Vol+** disables them.
   - **Vol−** keeps them.
   - With no key press in 10 s, the previous choice is kept ("keep" on a first install).
4. Reboot.

### ColorOS dynamic Calendar (optional, separate download)

1. Download `Calendar_17.6.30.apk` from the same release.
2. Open it on the phone and install it like any app. Allow installs from your browser or
   file manager if Android asks.

The launcher then shows the dynamic date icon. The APK is the unmodified, OPPO-signed
global ColorOS Calendar (`com.oplus.calendar`), installed as a normal app. It is in
English and has Indian public and religious holidays and Panchang. You don't need root
for this part, and the module isn't needed for the Calendar to work.

Releases up to v1.2 shipped the China Calendar (`com.coloros.calendar` 17.3.80) instead.
It shows Chinese lunar dates and festivals. If you installed it, uninstall it before or
after installing the global one, so you don't have two Calendar apps.

### Calendar holidays in Hindi? (optional, root)

OPPO's holiday service sends the **Holidays in India** list in Hindi, even when the phone
is set to English, and the Calendar has no setting to change that.
[`tools/calendar_holidays_en.py`](tools/calendar_holidays_en.py) translates the
downloaded list to English (Google's English holiday names) over adb.

```
python tools/calendar_holidays_en.py --dry-run   # preview
python tools/calendar_holidays_en.py             # apply
```

- **Requirements:** Python 3, adb, and root.
- **Which Calendar:** the script targets the global Calendar (`com.oplus.calendar`) from
  the release page. For the older China Calendar, add `--package com.coloros.calendar`.
- **When to run it again:** the Calendar downloads a new list now and then, and the
  new list is in Hindi. Run the script again when that happens.
- **Backups:** kept on the PC (`tools/calendar_legal_holiday.<time>.xml`) and on the
  phone (`calendar_legal_holiday.xml.hindi`).

If you'd rather not use root, turn off **Public holidays** in Calendar settings and
subscribe to Google's English **Holidays in India** calendar in your Google account.

### Changing the Google option later

Edit `/data/adb/cos17comms.conf`, set `DISABLE_GOOGLE=1` (disable) or `DISABLE_GOOGLE=0`
(keep or re-enable), then reboot.

For safety, the Google apps are only disabled while ColorOS Phone and ColorOS Messages
**are** the default dialer and SMS apps, so you can never end up without a working dialer.
They are disabled, not uninstalled. Disabling Google Messages also turns off its RCS chat.

## Logs

Logs are written to `/data/adb/modules/COS17CommsEnabler/`:

- `post-fs-data.log`: the `app_v2.xml` patch and bind mount
- `service.log`: enabling apps, default apps and the Google option

## Uninstall

Remove the module in the manager and reboot. The Google Dialer and Messages are restored
as the default apps. If you installed ColorOS Calendar, uninstall it from Settings like any
other app.

## Building from source

* **Module zip:** run `python build.py`. The output is `COS17CommsEnabler_<version>.zip`.
* **All-in-one zip (optional):** the module also installs a bundled Calendar after boot.
  1. Get the global ColorOS Calendar APK (`com.oplus.calendar`), for example
     `Calendar_17.6.30.apk` from the release page.
  2. Save it as `apk/Calendar.apk`. It is git-ignored and never committed.
  3. Run `python build.py --with-calendar`.

## License

The module's scripts and build tooling are released under the [MIT License](LICENSE).
The license does **not** cover the ColorOS Calendar APK on the release page, which
remains OPPO's property.

## Disclaimer

ColorOS, the ColorOS Calendar app and all related trademarks belong to OPPO / OnePlus.
This module only changes configuration on your own device. Use it at your own risk, and
keep a backup.

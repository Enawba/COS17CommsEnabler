# COS17 Comms Enabler

A KernelSU / Magisk module for **ColorOS 17 outside China** (India, global, EU). It brings
back the stock ColorOS communication apps in place of the Google ones:

- **ColorOS Contacts + Phone (new UI)**: `com.android.contacts` and `com.android.incallui`
- **ColorOS Messages**: `com.android.mms`, on firmware that includes it (see
  [Supported devices](#supported-devices))
- *Optional:* disables **Google Dialer** and **Google Messages**
- **English public holidays** for your region in the ColorOS Calendar, with an **Action**
  button to apply them on demand
- **ColorOS dynamic Calendar** (`com.oplus.calendar` 17.6.30, the global build) is a
  **separate APK** on the release page. It is not part of the module zip.

Tested target: OnePlus 12 (CPH2573, India) on ColorOS 17 with KernelSU-Next.

## Supported devices

One module zip serves every region. At each boot it checks what the firmware contains and
adapts, so there are no region-specific branches to choose from.

| Firmware | Contacts + Phone | Messages | Calendar holidays |
|---|---|---|---|
| ColorOS 17 India (e.g. OnePlus 12 CPH2573) | ✅ enabled | ✅ enabled | ✅ English list for your region |
| ColorOS 17 EU/global (e.g. OnePlus Open) | ✅ enabled; the module also adds the 2 ColorOS-dialer feature flags this firmware lacks | ➕ not in the firmware: flash the [Messages add-on](#messages-add-on-for-roms-without-coloros-messages), or Google Messages stays | ✅ English list for your region |

The OnePlus Open EU firmware ships the same ColorOS Contacts (17.20.80) and InCallUI
(17.6.10) as the India build, disabled by the same `app_v2.xml` lines. It does **not** ship
ColorOS Messages. The firmware's permission lists already include ColorOS Messages, so the
permissions are the same as on the India build. A separate branch per region is therefore
not needed. On a OnePlus Open, the module is not yet tested on a real device.

## How it works

The India/global ColorOS 17 firmware already ships ColorOS Contacts, InCallUI and Messages
in `/my_stock/priv-app`, at the same versions as the China build. They are only switched off
by three lines in `/my_stock/etc/config/app_v2.xml` (and, on some firmware, in
`/my_region/etc/config/app_v2.xml`):

```xml
<disable pkg="com.android.contacts" priority="10"/>
<disable pkg="com.android.incallui" priority="10"/>
<disable pkg="com.android.mms" priority="10"/>
```

| Step | Script | What happens |
|---|---|---|
| Boot (early) | `post-fs-data.sh` | Reads the device's **own** `app_v2.xml` files, removes only those lines and bind-mounts the result over the originals. Firmware without the ColorOS-dialer feature flags (`com.android.phone.oplus_dialer_enable` and `com.android.server.telecom.oplus_dialer_enable`) gets them added the same way. All of this is rebuilt every boot, so future OTA changes to those files are kept. |
| Boot completed | `service.sh` | Re-enables the ColorOS apps that the firmware has, if an earlier boot disabled them. |
| First boot only | `service.sh` | Makes ColorOS Phone the default dialer and ColorOS Messages (if present) the default SMS app. You can change defaults freely afterwards. |
| Optional | `service.sh` | Disables Google Dialer and/or Google Messages (see below). |
| Boot + every 6 h | `service.sh` | Puts the English holiday list for your region into the Calendar (see below). |
| Action button | `action.sh` | Does the same holiday step right away. |
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
global ColorOS Calendar (`com.oplus.calendar`), installed as a normal app. It has public
and religious holidays and regional calendars such as Panchang. You don't need root for
this part, and the module isn't needed for the Calendar to work.

Releases up to v1.2 shipped the China Calendar (`com.coloros.calendar` 17.3.80) instead.
It shows Chinese lunar dates and festivals. If you installed it, uninstall it before or
after installing the global one, so you don't have two Calendar apps.

### Messages add-on (for ROMs without ColorOS Messages)

Some ColorOS 17 firmware, such as the OnePlus Open EU/global build, doesn't ship ColorOS
Messages. `COS17MessagesAddon_<version>.zip` on the release page (98 MB) adds it as a
system app:

- **What's inside:** the unmodified, OPPO-signed ColorOS Messages
  (`com.android.mms` 17.62.60) from the ColorOS 17 India firmware.
- **Where it goes:** `/system/priv-app/COS17Mms`, through the module's systemless overlay,
  with its native libraries unpacked next to it as on OPPO's own firmware.
- **Permissions:** a `privapp-permissions` file grants Messages the same 21 privileged
  permissions it has on the India firmware. The OnePlus Open firmware's own permission
  lists already name it, with identical entries.

1. Install **COS17 Comms Enabler v1.6 or newer** (needed: it lifts the firmware's block on
   ColorOS Messages and makes it the default SMS app).
2. Flash the add-on in the same manager and reboot.

The add-on refuses to install on firmware that already has ColorOS Messages (for example
the India build), because COS17 Comms Enabler enables the built-in one there. If you remove
the add-on, the next boot gives the SMS role back to Google Messages.

> **Status:** built from the firmware files and checked against them, but **not yet tested
> on a real OnePlus Open**. Keep a backup and report your logs.

### English public holidays for your region

The Calendar downloads the public holidays of the region chosen in **Calendar → Settings →
Holidays** from OPPO's server. The list is Google's "Holidays in &lt;country&gt;" calendar,
but often in the local language: India's comes in Hindi even on English phones. The module
replaces it with **Google's English list for the same region**.

- **Regions:** English lists for 70 regions are bundled in the module, covering 2025 to
  2031 (Google publishes less for a few countries). The module needs no internet access
  for this.
- **Region choice:** the module follows the region set in the Calendar. To get another
  region's holidays, change it there, then press **Action** or reboot.
- **When:**
  - **At boot:** if the Calendar is already running, the module closes it first.
  - **Every 6 hours:** only while the Calendar is closed, so it never closes the app
    while you're using it.
  - **Action button:** press it in the KernelSU / Magisk manager to apply the list right
    away. It runs even when the automatic part is turned off, and shows a step-by-step
    log (region, list used, whether the Calendar was closed, backup, verification).
- **What it changes:** only the region's holiday list, not your events or the religious
  holidays. OPPO's version number is kept, so the Calendar still downloads real updates;
  the next run replaces them with the English list again. The last original list is kept
  in the module folder (`holidays_original_<package>.xml`).
- **Which Calendar:** the global Calendar (`com.oplus.calendar`) and the older China one
  (`com.coloros.calendar`).
- **Turning the automatic part off:** set `TRANSLATE_HOLIDAYS=0` in
  `/data/adb/cos17comms.conf`.

[`tools/holidays.py`](tools/holidays.py) does the same from a PC (Python 3, adb, root),
with a fresh download from Google:

```
python tools/holidays.py apply --dry-run   # preview
python tools/holidays.py apply             # apply
python tools/holidays.py apply --country DE --package com.coloros.calendar
python tools/holidays.py update            # refresh the bundled lists (maintainers)
```

If you'd rather not use root, turn off **Public holidays** in Calendar settings and
subscribe to Google's English holiday calendar for your country in your Google account.

### Changing the options later

Edit `/data/adb/cos17comms.conf`, then reboot:

- `DISABLE_GOOGLE=1` disables the Google apps; `DISABLE_GOOGLE=0` keeps them or turns them back on.
- `TRANSLATE_HOLIDAYS=1` turns the automatic English holidays on (the default);
  `TRANSLATE_HOLIDAYS=0` turns them off.

For safety, each Google app is only disabled while its ColorOS replacement **is** the
default app: Google Dialer while ColorOS Phone is the default dialer, and Google Messages
while ColorOS Messages is the default SMS app. You can never end up without a working
dialer or SMS app, and on firmware without ColorOS Messages, Google Messages always stays.
The apps are disabled, not uninstalled. Disabling Google Messages also turns off its RCS chat.

## Logs

Logs are written to `/data/adb/modules/COS17CommsEnabler/`:

- `post-fs-data.log`: the `app_v2.xml` / feature-flag patches and bind mounts
- `service.log`: enabling apps, default apps, the Google option and the holiday lists
  (including Action button runs)

## Uninstall

Remove the module in the manager and reboot. The Google Dialer and Messages are restored
as the default apps. If you installed ColorOS Calendar, uninstall it from Settings like any
other app. If you keep it, its holidays stay in English until the Calendar downloads a new
list.

## Building from source

* **Module zip:** run `python build.py`. The output is `COS17CommsEnabler_<version>.zip`.
  It packs the English holiday lists from `holidays/*.json`; refresh them with
  `python tools/holidays.py update`.
* **All-in-one zip (optional):** the module also installs a bundled Calendar after boot.
  1. Get the global ColorOS Calendar APK (`com.oplus.calendar`), for example
     `Calendar_17.6.30.apk` from the release page.
  2. Save it as `apk/Calendar.apk`. It is git-ignored and never committed.
  3. Run `python build.py --with-calendar`.
* **Messages add-on:**
  1. Extract `my_stock/priv-app/Mms/Mms.apk` from a ColorOS 17 **India** firmware.
  2. Save it as `apk/Mms.apk`. It is git-ignored and never committed.
  3. Run `python build.py --messages-addon`. The output is
     `COS17MessagesAddon_<version>.zip`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

The module's scripts and build tooling are released under the [MIT License](LICENSE).
The license does **not** cover the ColorOS Calendar APK on the release page or the
ColorOS Messages APK inside the Messages add-on, which remain OPPO's property. The holiday lists in `holidays/` come from Google's public
holiday calendars.

## Disclaimer

ColorOS, the ColorOS Calendar app and all related trademarks belong to OPPO / OnePlus.
This module only changes configuration on your own device. Use it at your own risk, and
keep a backup.

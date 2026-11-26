# COS17 Comms Enabler

A KernelSU / Magisk module for **ColorOS 17 (India / global builds)**. It brings back the
stock ColorOS communication apps in place of the Google ones:

- **ColorOS Contacts + Phone (new UI)**: `com.android.contacts` and `com.android.incallui`
- **ColorOS Messages**: `com.android.mms`
- **ColorOS dynamic Calendar** (`com.coloros.calendar` 17.3.80, taken from the China build)
- *Optional:* disables **Google Dialer** and **Google Messages**

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
| Boot completed | `service.sh` | Re-enables the three apps if an earlier boot disabled them, and installs ColorOS Calendar if it is missing or older. |
| First boot only | `service.sh` | Makes ColorOS Phone the default dialer and ColorOS Messages the default SMS app. You can change defaults freely afterwards. |
| Optional | `service.sh` | Disables Google Dialer + Google Messages (see below). |
| Module removed | `uninstall.sh` | Re-enables the Google apps and makes them the default dialer / SMS app again. |

No China-only features are enabled (China Mobile video calling, Chinese number tagging and
similar), because they make no sense with non-Chinese SIM cards.

## Install

1. Download the zip from [Releases](../../releases).
2. Flash it in the KernelSU / KernelSU-Next / Magisk manager.
3. When asked **"Disable Google Dialer + Google Messages?"**:
   - **Vol+** disables them.
   - **Vol−** keeps them.
   - With no key press in 10 s, the previous choice is kept ("keep" on a first install).
4. Reboot, then wait about 30 s after boot for the Calendar to be installed.

### Changing the Google option later

Edit `/data/adb/cos17comms.conf`, set `DISABLE_GOOGLE=1` (disable) or `DISABLE_GOOGLE=0`
(keep or re-enable), then reboot.

For safety, the Google apps are only disabled while ColorOS Phone and ColorOS Messages
**are** the default dialer and SMS apps, so you can never end up without a working dialer.
They are disabled, not uninstalled. Disabling Google Messages also turns off its RCS chat.

## Logs

Logs are written to `/data/adb/modules/COS17CommsEnabler/`:

- `post-fs-data.log`: the `app_v2.xml` patch and bind mount
- `service.log`: enabling apps, the Calendar install, default apps and the Google option

## Uninstall

Remove the module in the manager and reboot. The Google Dialer and Messages are restored
as the default apps. ColorOS Calendar stays installed; uninstall it from Settings if you
don't want it.

## Building from source

The repository does not contain the Calendar APK. To build the zip yourself:

1. Extract `my_stock/del-app/Calendar/Calendar.apk` from a ColorOS 17 **China** firmware.
2. Save it as `apk/OPlusCalendar.apk`.
3. Run `python build.py`. The output is `COS17CommsEnabler_<version>.zip`.

## License

The module's scripts and build tooling are released under the [MIT License](LICENSE).
The license does **not** cover the ColorOS Calendar APK bundled in the release zip, which
remains OPPO's property.

## Disclaimer

ColorOS, the ColorOS Calendar app and all related trademarks belong to OPPO / OnePlus.
This module only changes configuration on your own device. Use it at your own risk, and
keep a backup.

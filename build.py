"""Build the flashable module zip.

    python build.py                  # module only (the normal release zip)
    python build.py --with-calendar  # also bundle apk/Calendar.apk (all-in-one zip)
    python build.py --messages-addon # COS17 Messages add-on from apk/Mms.apk

apk/Mms.apk = ColorOS 17 India: my_stock/priv-app/Mms/Mms.apk (com.android.mms)

apk/Calendar.apk = ColorOS global Calendar (com.oplus.calendar), e.g. Calendar_17.6.30.apk

holidays/<CC>.json (English holidays per region, refreshed with
`python tools/holidays.py update`) are packed as holidays/<CC>: the JSON array
already escaped for the Calendar's shared_prefs XML, ready for holidays.sh to insert.
"""
import glob
import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
import holidays  # noqa: E402

ROOT = os.path.dirname(os.path.abspath(__file__))
INCLUDE = ["META-INF/com/google/android/update-binary",
           "META-INF/com/google/android/updater-script",
           "module.prop", "customize.sh", "post-fs-data.sh", "service.sh", "action.sh",
           "holidays.sh", "uninstall.sh", "LICENSE"]
CALENDAR = "apk/Calendar.apk"
EXECUTABLE = (".sh", "update-binary")
DATE = (2026, 1, 1, 0, 0, 0)


def add(z, name, data, mode=0o644, stored=False):
    info = zipfile.ZipInfo(name, date_time=DATE)
    info.external_attr = mode << 16
    info.compress_type = zipfile.ZIP_STORED if stored else zipfile.ZIP_DEFLATED
    z.writestr(info, data)


def messages_addon():
    """ColorOS Messages as a system app for ROMs without it (e.g. OnePlus Open EU)."""
    src = os.path.join(ROOT, "addons", "messages")
    apk = os.path.join(ROOT, "apk", "Mms.apk")
    if not os.path.exists(apk):
        sys.exit("apk/Mms.apk is missing - see README 'Building from source'")
    props = dict(l.split("=", 1) for l in open(os.path.join(src, "module.prop"),
                                                encoding="utf-8").read().splitlines() if "=" in l)
    app = "system/priv-app/COS17Mms"
    out = os.path.join(ROOT, f"{props['id']}_{props['version']}.zip")
    apk_zip = zipfile.ZipFile(apk)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel, path in [("META-INF/com/google/android/update-binary", None),
                          ("META-INF/com/google/android/updater-script", None),
                          ("LICENSE", None),
                          ("module.prop", os.path.join(src, "module.prop")),
                          ("customize.sh", os.path.join(src, "customize.sh")),
                          ("system/etc/permissions/privapp-permissions-cos17-mms.xml",
                           os.path.join(src, "privapp-permissions-cos17-mms.xml"))]:
            data = open(path or os.path.join(ROOT, *rel.split("/")), "rb").read()
            if b"\r\n" in data:
                sys.exit(f"{rel} has CRLF line endings - fix before building")
            add(z, rel, data, 0o755 if rel.endswith(EXECUTABLE) else 0o644)
        add(z, f"{app}/COS17Mms.apk", open(apk, "rb").read(), stored=True)
        # extractNativeLibs=true: a system app needs its libraries unpacked next to it
        libs = [i for i in apk_zip.infolist() if i.filename.startswith("lib/arm64-v8a/")]
        for i in libs:
            add(z, f"{app}/lib/arm64/{os.path.basename(i.filename)}", apk_zip.read(i))
    print(f"built {out} ({os.path.getsize(out) / 1e6:.1f} MB, {len(libs)} libraries)")


def main():
    if "--messages-addon" in sys.argv[1:]:
        return messages_addon()
    with_calendar = "--with-calendar" in sys.argv[1:]
    props = dict(l.split("=", 1) for l in open(os.path.join(ROOT, "module.prop"),
                                                encoding="utf-8").read().splitlines() if "=" in l)
    files = list(INCLUDE)
    suffix = ""
    if with_calendar:
        if not os.path.exists(os.path.join(ROOT, *CALENDAR.split("/"))):
            sys.exit(f"{CALENDAR} is missing - see README 'Building from source'")
        files.append(CALENDAR)
        suffix = "_with_calendar"
    regions = sorted(glob.glob(os.path.join(ROOT, "holidays", "*.json")))
    if not regions:
        sys.exit("holidays/*.json missing - run: python tools/holidays.py update")
    out = os.path.join(ROOT, f"{props['id']}_{props['version']}{suffix}.zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in files:
            data = open(os.path.join(ROOT, *rel.split("/")), "rb").read()
            if not rel.endswith(".apk") and b"\r\n" in data:
                sys.exit(f"{rel} has CRLF line endings - fix before building")
            add(z, rel, data, 0o755 if rel.endswith(EXECUTABLE) else 0o644, rel.endswith(".apk"))
        for path in regions:
            entries = json.load(open(path, encoding="utf-8"))
            cc = os.path.splitext(os.path.basename(path))[0]
            add(z, f"holidays/{cc}", holidays.data_array(entries).encode("utf-8"))
    print(f"built {out} ({os.path.getsize(out) / 1e6:.2f} MB, {len(regions)} holiday regions)")


if __name__ == "__main__":
    main()

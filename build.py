"""Build the flashable module zip: python build.py

Needs apk/OPlusCalendar.apk (ColorOS 17 CN: my_stock/del-app/Calendar/Calendar.apk).
"""
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
INCLUDE = ["META-INF/com/google/android/update-binary",
           "META-INF/com/google/android/updater-script",
           "module.prop", "customize.sh", "post-fs-data.sh", "service.sh", "uninstall.sh",
           "apk/OPlusCalendar.apk"]
EXECUTABLE = (".sh", "update-binary")


def main():
    props = dict(l.split("=", 1) for l in open(os.path.join(ROOT, "module.prop"),
                                                encoding="utf-8").read().splitlines() if "=" in l)
    apk = os.path.join(ROOT, "apk", "OPlusCalendar.apk")
    if not os.path.exists(apk):
        sys.exit("apk/OPlusCalendar.apk is missing - see README 'Building from source'")
    out = os.path.join(ROOT, f"{props['id']}_{props['version']}.zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in INCLUDE:
            path = os.path.join(ROOT, *rel.split("/"))
            data = open(path, "rb").read()
            if not rel.endswith(".apk") and b"\r\n" in data:
                sys.exit(f"{rel} has CRLF line endings - fix before building")
            info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
            info.external_attr = (0o755 if rel.endswith(EXECUTABLE) else 0o644) << 16
            info.compress_type = zipfile.ZIP_STORED if rel.endswith(".apk") else zipfile.ZIP_DEFLATED
            z.writestr(info, data)
    print(f"built {out} ({os.path.getsize(out) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()

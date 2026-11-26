"""English public-holiday lists for the ColorOS Calendar.

The ColorOS Calendar downloads the holidays of the region chosen in
Calendar > Settings > Holidays from OPPO's server. The list is Google's
"Holidays in <country>" calendar, but often in the local language: India, for
example, comes in Hindi even on English phones. The module replaces that list with
Google's ENGLISH version for the same region. The English lists are bundled in
holidays/<CC>.json and are refreshed with this script.

    python tools/holidays.py update              # re-download holidays/*.json (maintainers)
    python tools/holidays.py apply [--dry-run]   # put the English list on a phone now (adb + root)
           [--package com.coloros.calendar]      #   China Calendar instead of the global one
           [--country DE]                        #   force a region instead of the selected one

`apply` does what the module does at boot or with its Action button, but straight away
from a PC and with a fresh download from Google.
"""
import html
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "holidays")
FIRST_YEAR = 2025          # oldest year kept in the bundled lists

# ISO country code (as stored by the Calendar) -> Google holiday calendar id
COUNTRIES = {
    "AE": "ae", "AR": "ar", "AT": "austrian", "AU": "australian", "BD": "bd",
    "BE": "be", "BG": "bulgarian", "BR": "brazilian", "CA": "canadian", "CH": "ch",
    "CL": "cl", "CN": "china", "CO": "co", "CZ": "czech", "DE": "german",
    "DK": "danish", "DZ": "dz", "EE": "ee", "EG": "eg", "ES": "spain",
    "FI": "finnish", "FR": "french", "GB": "uk", "GR": "greek", "HK": "hong_kong",
    "HR": "croatian", "HU": "hungarian", "ID": "indonesian", "IE": "irish",
    "IN": "indian", "IQ": "iq", "IT": "italian", "JP": "japanese", "KE": "ke",
    "KR": "south_korea", "KW": "kw", "KZ": "kz", "LK": "lk", "LT": "lithuanian",
    "LU": "lu", "LV": "latvian", "MA": "ma", "MX": "mexican", "MY": "malaysia",
    "NG": "ng", "NL": "dutch", "NO": "norwegian", "NP": "np", "NZ": "new_zealand",
    "PE": "pe", "PH": "philippines", "PK": "pk", "PL": "polish", "PT": "portuguese",
    "QA": "qa", "RO": "romanian", "RS": "rs", "RU": "russian", "SA": "saudiarabian",
    "SE": "swedish", "SG": "singapore", "SI": "slovenian", "SK": "slovak", "TH": "th",
    "TR": "turkish", "TW": "taiwan", "UA": "ukrainian", "US": "usa", "VN": "vietnamese",
    "ZA": "sa",
}
ICS_URL = ("https://calendar.google.com/calendar/ical/"
           "en.{}%23holiday%40group.v.calendar.google.com/public/basic.ics")

PKG = "com.oplus.calendar"
KEY = "calendar_country_holiday_content"
TMP = "/data/local/tmp/calendar_legal_holiday.xml"


# ---- Google calendar -> Calendar entries -----------------------------------------
def _unescape(v):
    return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) in "nN" else m.group(1), v)


def fetch(cc):
    """English holidays of one country, in the Calendar's own entry format."""
    url = ICS_URL.format(COUNTRIES[cc])
    with urllib.request.urlopen(url, timeout=60) as r:
        text = r.read().decode("utf-8")
    lines = re.sub(r"\r?\n[ \t]", "", text).splitlines()   # unfold
    name = next(l.split(":", 1)[1] for l in lines if l.startswith("X-WR-CALNAME:"))
    entries, ev = [], None
    for l in lines:
        if l == "BEGIN:VEVENT":
            ev = {}
        elif l == "END:VEVENT":
            start, end = ev.get("DTSTART", ""), ev.get("DTEND", "")
            if len(start) == 8 and int(start[:4]) >= FIRST_YEAR:
                d = lambda s: f"{s[:4]}-{s[4:6]}-{s[6:8]}"
                entries.append({"summary": ev.get("SUMMARY", ""),
                                "description": ev.get("DESCRIPTION", ""),
                                "organizer": _unescape(name),
                                "start": d(start), "end": d(end or start)})
            ev = None
        elif ev is not None and ":" in l:
            k, v = l.split(":", 1)
            ev[k.split(";")[0]] = _unescape(v)
    entries.sort(key=lambda e: (e["start"], e["summary"]))
    return entries


def xml_escape(s):
    """How Android's shared_prefs writer escapes a string value."""
    return html.escape(s, quote=True).replace("&#x27;", "'")


def data_array(entries):
    """The JSON "data" array, escaped for the shared_prefs XML (what the module inserts)."""
    return xml_escape(json.dumps(entries, ensure_ascii=False, separators=(",", ":")))


def update():
    os.makedirs(DATA, exist_ok=True)
    for cc in sorted(COUNTRIES):
        entries = fetch(cc)
        with open(os.path.join(DATA, f"{cc}.json"), "w", encoding="utf-8", newline="\n") as f:
            f.write("[\n" + ",\n".join(json.dumps(e, ensure_ascii=False) for e in entries)
                    + "\n]\n")
        print(f"{cc}: {len(entries)} holidays, {entries[0]['start']} .. {entries[-1]['start']}")


# ---- phone ------------------------------------------------------------------------
def adb(*args):
    r = subprocess.run(["adb", *args], capture_output=True)
    if r.returncode:
        sys.exit(f"adb {' '.join(args)} failed:\n{r.stderr.decode(errors='replace')}")
    return r.stdout


def apply(pkg, country, dry):
    pref = f"/data/data/{pkg}/shared_prefs/calendar_legal_holiday.xml"
    xml = adb("exec-out", f"su -c 'cat {pref}'").decode("utf-8")
    m = re.search(rf'(<string name="{KEY}">)(.*?)(</string>)', xml, re.S)
    if not m:
        sys.exit("No holiday list yet - choose a region in Calendar > Settings > Holidays.")
    cur = json.loads(html.unescape(m.group(2)))
    sel = re.search(r'name="sp_key_calendar_holiday_country_code">(\w+)<', xml)
    cc = (country or (sel.group(1) if sel else "")).upper()
    if cc not in COUNTRIES:
        sys.exit(f"No English holiday list known for region '{cc}'.")
    entries = fetch(cc)
    print(f"{pkg}: region {cc}, server version {cur.get('version')}, "
          f"{len(cur.get('data', []))} entries -> {len(entries)} English entries")
    value = xml_escape(json.dumps({"version": cur.get("version", "0"), "data": entries},
                                  ensure_ascii=False, separators=(",", ":")))
    new = xml[:m.start(2)] + value + xml[m.end(2):]
    if dry:
        for e in entries[:6]:
            print(f"  {e['start']}  {e['summary']}")
        print("dry run - phone not changed")
        return
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, f"calendar_legal_holiday.{time.strftime('%Y%m%d-%H%M%S')}.xml"),
              "w", encoding="utf-8", newline="") as f:
        f.write(xml)
    local = os.path.join(here, "calendar_legal_holiday.new.xml")
    with open(local, "w", encoding="utf-8", newline="") as f:
        f.write(new)
    adb("shell", "am", "force-stop", pkg)
    adb("push", local, TMP)
    os.remove(local)
    adb("shell", f"su -c 'cat {TMP} > {pref} && rm -f {TMP} {pref}.bak'")  # cat keeps owner/label
    if adb("exec-out", f"su -c 'cat {pref}'").decode("utf-8") != new:
        sys.exit("Verification failed - the backup next to this script has the original.")
    print("Done. Open Calendar - holidays are now in English.")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if args[:1] == ["update"]:
        update()
    elif args[:1] == ["apply"]:
        opt = lambda k: args[args.index(k) + 1] if k in args[:-1] else None
        apply(opt("--package") or PKG, opt("--country"), "--dry-run" in args)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()

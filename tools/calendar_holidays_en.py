"""Translate the ColorOS Calendar's cached India holidays (Hindi) to English.

    python calendar_holidays_en.py            # translate + write back to the phone
    python calendar_holidays_en.py --dry-run  # only show what would change

Needs adb + root (KernelSU). Re-run whenever the Calendar downloads a new holiday
list (it comes back in Hindi). A backup of the original file is kept on the PC
(calendar_legal_holiday.<time>.xml) and on the phone (*.xml.hindi).
"""
import html
import json
import os
import re
import subprocess
import sys
import time

PKG = "com.oplus.calendar"
PREF = f"/data/data/{PKG}/shared_prefs/calendar_legal_holiday.xml"
TMP = "/data/local/tmp/calendar_legal_holiday.xml"
KEY = "calendar_country_holiday_content"

NAMES = {
    "अम्बेडकर जयंती": "Dr. Ambedkar Jayanti",
    "उगादि": "Ugadi",
    "ओणम": "Onam",
    "कर्क चतुर्थी": "Karaka Chaturthi (Karva Chauth)",
    "क्रिसमस/ बड़ा दिन": "Christmas",
    "गणतंत्र दिवस": "Republic Day",
    "गणेश चतुर्थी": "Ganesh Chaturthi / Vinayaka Chaturthi",
    "गुड फ्राइडे": "Good Friday",
    "गुड़ी पड़वा": "Gudi Padwa",
    "गुरु गोबिंद सिंह जयंती": "Guru Govind Singh Jayanti",
    "गुरु तेग बहादुर शहीदी दिवस": "Guru Tegh Bahadur's Martyrdom Day",
    "गुरु रविदास जयंती": "Guru Ravidas Jayanti",
    "गुरू नानक जयंती": "Guru Nanak Jayanti",
    "गोवर्धन पूजा": "Govardhan Puja",
    "चैत्र सुखलदि": "Chaitra Sukhladi",
    "छठ पूजा": "Chhat Puja (Pratihar Sashthi/Surya Sashthi)",
    "जन्माष्टमी": "Janmashtami",
    "जन्माष्टमी स्मार्त": "Janmashtami (Smarta)",
    "जमात उल विदा": "Jamat Ul-Vida",
    "डोलयात्रा": "Dolyatra",
    "दशहरा": "Dussehra",
    "दशहरा/महा नवमी": "Dussehra / Maha Navami",
    "दीवाली/ दीपावली": "Diwali / Deepavali",
    "दुर्गा पूजा उत्सव का पहला दिन": "First Day of Durga Puja Festivities",
    "नरका चतुर्दशी": "Naraka Chaturdasi",
    "पहली जनवरी": "New Year's Day",
    "पारसी नव वर्ष": "Parsi New Year",
    "पोंगल": "Pongal",
    "बकर-ईद": "Bakrid / Eid ul-Adha",
    "बड़े दिन की पूर्व संध्या": "Christmas Eve",
    "बुद्ध पूर्णिमा": "Buddha Purnima / Vesak",
    "भैया दूज": "Bhai Duj",
    "मकर संक्रांति": "Makar Sankranti",
    "महर्षि दयानंद सरस्वती जयंती": "Maharishi Dayanand Saraswati Jayanti",
    "महर्षि वाल्मीकि जयंती": "Maharishi Valmiki Jayanti",
    "महा अष्टमी": "Maha Ashtami",
    "महा शिवरात्रि": "Maha Shivaratri / Shivaratri",
    "महा सप्तमी": "Maha Saptami",
    "महात्मा गांधी जयंती": "Mahatma Gandhi Jayanti",
    "महावीर जयंती": "Mahavir Jayanti",
    "मिलाद उन नबी": "Milad un-Nabi / Id-e-Milad",
    "मुहर्रम": "Muharram / Ashura",
    "मेसाडी": "Mesadi / Vaisakhadi",
    "रक्षा बंधन": "Raksha Bandhan (Rakhi)",
    "रथ यात्रा": "Rath Yatra",
    "रमज़ान शुरू": "Ramadan Start",
    "रमजान ईद/ईद उल फितर": "Ramzan Id / Eid-ul-Fitar",
    "रवीन्द्रनाथ का जन्मदिन": "Rabindranath Tagore Jayanti",
    "रामनवमी": "Rama Navami",
    "वसंत पंचमी": "Vasant Panchami",
    "वैसाखी": "Vaisakhi",
    "शरद नवरात्रि का पहला दिन": "First Day of Sharad Navratri",
    "शिवाजी जयंती": "Chhatrapati Shivaji Maharaj Jayanti",
    "स्वतंत्रता दिवस": "Independence Day",
    "हजरत अली का जन्मदिन": "Hazarat Ali's Birthday",
    "होलिका दहन": "Holika Dahana",
    "होली": "Holi",
    # extra names that may appear in future lists
    "दीवाली": "Diwali / Deepavali",
    "ईस्टर": "Easter Day",
    "नवरोज़": "Navroz",
    "लोहड़ी": "Lohri",
    "करवा चौथ": "Karva Chauth",
    "क्रिसमस": "Christmas",
    "नया साल": "New Year's Day",
}
LINES = {
    "त्योहार": "Observance",
    "त्योहारों को छिपाने के लिए, Google Calendar की सेटिंग में > भारत की छुट्टियां पर जाएं":
        "To hide observances, go to Google Calendar Settings > Holidays in India",
    "सार्वजनिक छुट्टी": "Public holiday",
    "यह छुट्टी की अनुमानित तारीख है और इसमें बदलाव हो सकता है.":
        "Date of this holiday is tentative and may change.",
    "भारत की छुट्टियां": "Holidays in India",
}
TENTATIVE = "(पक्का नहीं है)"
DEVANAGARI = re.compile("[ऀ-ॿ]")


def adb(*args, data=None):
    r = subprocess.run(["adb", *args], input=data, capture_output=True)
    if r.returncode:
        sys.exit(f"adb {' '.join(args)} failed:\n{r.stderr.decode(errors='replace')}")
    return r.stdout


def su(cmd):
    return adb("shell", f"su -c '{cmd}'").decode(errors="replace")


def tr_summary(s, unknown):
    t = s.strip()
    suffix = ""
    if t.endswith(TENTATIVE):
        t, suffix = t[: -len(TENTATIVE)].strip(), " (tentative)"
    if t in NAMES:
        return NAMES[t] + suffix
    if DEVANAGARI.search(t):
        unknown.add(s.strip())
    return s


def tr_lines(s, unknown):
    out = []
    for line in s.split("\n"):
        t = line.strip()
        if t in LINES:
            out.append(LINES[t])
        else:
            if DEVANAGARI.search(t):
                unknown.add(t)
            out.append(line)
    return "\n".join(out).strip()


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    dry = "--dry-run" in sys.argv[1:]
    here = os.path.dirname(os.path.abspath(__file__))

    xml = adb("exec-out", f"su -c 'cat {PREF}'").decode("utf-8")
    m = re.search(rf'(<string name="{KEY}">)(.*?)(</string>)', xml, re.S)
    if not m:
        sys.exit("No country holiday list cached yet - open Calendar once, then re-run.")
    data = json.loads(html.unescape(m.group(2)))
    country = re.search(r'country_code">(\w+)<', xml)
    print(f"country {country.group(1) if country else '?'}, "
          f"version {data.get('version')}, {len(data['data'])} entries")

    unknown, changed = set(), 0
    for e in data["data"]:
        before = (e.get("summary"), e.get("description"), e.get("organizer"))
        e["summary"] = tr_summary(e.get("summary", ""), unknown)
        e["description"] = tr_lines(e.get("description", ""), unknown)
        e["organizer"] = tr_lines(e.get("organizer", ""), unknown)
        if before != (e["summary"], e["description"], e["organizer"]):
            changed += 1
    print(f"{changed} entries translated")
    for u in sorted(unknown):
        print(f"  ! no translation, kept as-is: {u}")
    if not changed:
        print("Nothing to do (already English?).")
        return

    value = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    value = html.escape(value, quote=True).replace("&#x27;", "'")
    new = xml[: m.start(2)] + value + xml[m.end(2):]
    if dry:
        for e in data["data"][:8]:
            print(f"  {e['start']}  {e['summary']}  [{e['description'].splitlines()[0]}]")
        print("dry run - phone not changed")
        return

    stamp = time.strftime("%Y%m%d-%H%M%S")
    with open(os.path.join(here, f"calendar_legal_holiday.{stamp}.xml"), "w",
              encoding="utf-8", newline="") as f:
        f.write(xml)

    adb("shell", "am", "force-stop", PKG)
    tmp_local = os.path.join(here, "calendar_legal_holiday.en.xml")
    with open(tmp_local, "w", encoding="utf-8", newline="") as f:
        f.write(new)
    adb("push", tmp_local, TMP)
    os.remove(tmp_local)
    # cat > keeps the original file's owner, mode and SELinux label
    su(f"[ -f {PREF}.hindi ] || {{ cp -p {PREF} {PREF}.hindi; "
       f"chcon $(ls -Z {PREF} | cut -d\" \" -f1) {PREF}.hindi; }}; "
       f"cat {TMP} > {PREF} && rm -f {TMP} {PREF}.bak")
    check = adb("exec-out", f"su -c 'cat {PREF}'").decode("utf-8")
    if check != new:
        sys.exit("Verification failed - restore with: "
                 f"adb shell su -c 'cat {PREF}.hindi > {PREF}'")
    print("Done. Open Calendar - holidays are now in English.")


if __name__ == "__main__":
    main()

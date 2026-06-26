#!/usr/bin/env python3
"""Generate ALL TOCFL vocabulary pack JSON files from 華語八千詞表20240923.xlsx"""
import openpyxl
import json
import csv
import sys
from collections import defaultdict

sys.stdout.reconfigure(encoding="utf-8")

XLSX_PATH = r"D:\CLAUDE\ZHONG-WEN-SHU-2\app\assets\packs\華語八千詞表20240923.xlsx"
CSV_PATH = r"D:\CLAUDE\ZHONG-WEN-SHU-2\app\assets\packs\tocfl_vocab_list.csv"
OUT_DIR = r"D:\CLAUDE\ZHONG-WEN-SHU-2\app\assets\packs"

from opencc import OpenCC
_t2s = OpenCC("t2s")

PRECOMPOSED_TONES = {
    # Standard pre-composed
    0x0101: 1, 0x00E1: 2, 0x01CE: 3, 0x00E0: 4,  # ā á ǎ à
    0x0113: 1, 0x00E9: 2, 0x011B: 3, 0x00E8: 4,  # ē é ě è
    0x012B: 1, 0x00ED: 2, 0x01D0: 3, 0x00EC: 4,  # ī í ǐ ì
    0x014D: 1, 0x00F3: 2, 0x01D2: 3, 0x00F2: 4,  # ō ó ǒ ò
    0x016B: 1, 0x00FA: 2, 0x01D4: 3, 0x00F9: 4,  # ū ú ǔ ù
    0x01D6: 1, 0x01D8: 2, 0x01DA: 3, 0x01DC: 4,  # ǖ ǘ ǚ ǜ
    # XLSX alternate diacritics (breve for tone 3)
    0x0103: 3,  # ă (a with breve)
    0x011D: 3,  # ĕ (e with breve)
    0x012D: 3,  # ĭ (i with breve)
    0x014E: 3,  # ŏ (o with breve)
    0x016D: 3,  # ŭ (u with breve)
}

BOPOMOFO_MAP = {
    "b": "ㄅ", "p": "ㄆ", "m": "ㄇ", "f": "ㄈ", "d": "ㄉ", "t": "ㄊ",
    "n": "ㄋ", "l": "ㄌ", "g": "ㄍ", "k": "ㄎ", "h": "ㄏ",
    "j": "ㄐ", "q": "ㄑ", "x": "ㄒ", "zh": "ㄓ", "ch": "ㄔ",
    "sh": "ㄕ", "r": "ㄖ", "z": "ㄗ", "c": "ㄘ", "s": "ㄙ",
    "y": "ㄧ", "w": "ㄨ",
}
VOWEL_BPMF = {
    "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "ê": "ㄝ", "ai": "ㄞ",
    "ei": "ㄟ", "ao": "ㄠ", "ou": "ㄡ", "an": "ㄢ", "en": "ㄣ",
    "ang": "ㄤ", "eng": "ㄥ", "er": "ㄦ",
    "i": "ㄧ", "u": "ㄨ", "ü": "ㄩ", "v": "ㄩ",
    "ia": "ㄧㄚ", "iao": "ㄧㄠ", "ian": "ㄧㄢ", "iang": "ㄧㄤ",
    "ie": "ㄧㄝ", "in": "ㄧㄣ", "ing": "ㄧㄥ", "iong": "ㄩㄥ",
    "iu": "ㄧㄡ", "ua": "ㄨㄚ", "uai": "ㄨㄞ", "uan": "ㄨㄢ",
    "uang": "ㄨㄤ", "ue": "ㄩㄝ", "ui": "ㄨㄟ", "un": "ㄨㄣ",
    "uo": "ㄨㄛ", "üe": "ㄩㄝ", "üan": "ㄩㄢ", "ün": "ㄩㄣ",
}
TONE_MARKS = {1: "", 2: "\u02ca", 3: "\u02c7", 4: "\u02cb", 5: "\u02d9"}


def pinyin_to_bopomofo(py_str):
    if not py_str:
        return ""
    py = py_str.lower().strip()
    # Normalize alternate diacritics to standard
    py = py.replace("ă", "ǎ").replace("ĕ", "ě").replace("ĭ", "ǐ").replace("ŏ", "ǒ").replace("ŭ", "ǔ")
    py = py.replace("ü", "v")
    py = py.replace("ā", "a1").replace("á", "a2").replace("ǎ", "a3").replace("à", "a4")
    py = py.replace("ē", "e1").replace("é", "e2").replace("ě", "e3").replace("è", "e4")
    py = py.replace("ī", "i1").replace("í", "i2").replace("ǐ", "i3").replace("ì", "i4")
    py = py.replace("ō", "o1").replace("ó", "o2").replace("ǒ", "o3").replace("ò", "o4")
    py = py.replace("ū", "u1").replace("ú", "u2").replace("ǔ", "u3").replace("ù", "u4")
    py = py.replace("ǖ", "v1").replace("ǘ", "v2").replace("ǚ", "v3").replace("ǜ", "v4")

    tone = 1
    for c in py:
        if c.isdigit():
            tone = int(c)
            break
    py_clean = "".join(c for c in py if not c.isdigit())

    initial = ""
    rest = py_clean
    for length in [6, 5, 4, 3, 2, 1]:
        candidate = py_clean[:length]
        if candidate in BOPOMOFO_MAP:
            initial = BOPOMOFO_MAP[candidate]
            rest = py_clean[length:]
            break

    final_bpmf = ""
    if rest:
        for length in [6, 5, 4, 3, 2, 1]:
            candidate = rest[:length]
            if candidate in VOWEL_BPMF:
                final_bpmf = VOWEL_BPMF[candidate]
                break
        if not final_bpmf:
            final_bpmf = rest

    result = initial + final_bpmf
    if tone == 5:
        result = TONE_MARKS[5] + result
    elif result:
        result = result + TONE_MARKS.get(tone, "")
    return result


def get_tone_from_bpmf(bpmf):
    if not bpmf:
        return None
    first = bpmf.split()[0] if " " in bpmf else bpmf
    if first.startswith("\u02d9"):
        return 5
    if first.endswith("\u02ca"):
        return 2
    if first.endswith("\u02c7"):
        return 3
    if first.endswith("\u02cb"):
        return 4
    return 1


def get_tone_from_pinyin(py):
    if not py:
        return 1
    for ch in py:
        cp = ord(ch)
        if cp in PRECOMPOSED_TONES:
            return PRECOMPOSED_TONES[cp]
    return 1


def to_simplified(trad):
    return _t2s.convert(trad)


def normalize_pinyin(p):
    return p.strip() if p else ""


def build_card(word, pinyin, pos="", tocfl_level=1):
    # Clean word
    if "/" in word:
        word_clean = word.split("/")[0].strip()
    else:
        word_clean = word.strip()

    # Clean pinyin
    if "/" in pinyin:
        py_clean = normalize_pinyin(pinyin.split("/")[0].strip())
    else:
        py_clean = normalize_pinyin(pinyin)

    # Remove inline bopomofo like (˙ㄊㄧㄢ)
    if "(" in py_clean and ")" in py_clean:
        py_clean = py_clean.split("(")[0].strip()

    bpmf = pinyin_to_bopomofo(py_clean)
    tone = get_tone_from_bpmf(bpmf)
    if tone is None:
        tone = get_tone_from_pinyin(py_clean)

    simplified = to_simplified(word_clean)

    return {
        "s": simplified,
        "t": word_clean,
        "py": py_clean,
        "zy": bpmf,
        "m": "",
        "tone": tone,
        "tocfl": tocfl_level,
    }


# ========== Read XLSX ==========
print("Reading XLSX...")
wb = openpyxl.load_workbook(XLSX_PATH, data_only=True)
xlsx_sheets = list(wb.sheetnames)[:7]  # First 7 sheets

xlsx_data = {}
for idx, sheet_name in enumerate(xlsx_sheets):
    ws = wb[sheet_name]
    words = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[0] is None and row[1] is None:
            continue
        if len(row) >= 4:
            word = str(row[1] or "").strip()
            pinyin = str(row[2] or "").strip()
            pos = str(row[3] or "").strip()
        elif len(row) >= 3:
            word = str(row[0] or "").strip()
            pinyin = str(row[1] or "").strip()
            pos = str(row[2] or "").strip()
        else:
            continue
        if word and pinyin:
            words.append((word, pinyin, pos))
    xlsx_data[idx] = words
    print(f"  Sheet {idx} ({sheet_name}): {len(words)} words")

# ========== Read CSV for Level 6 (band_c2) ==========
print("\nReading CSV for Level 6...")
csv_level6 = []
with open(CSV_PATH, "r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        band = row["等別"]
        level = row["級別"]
        word = row["詞語"].strip()
        pinyin = row["參考漢語拼音"].strip()
        eng = row["英文解釋"].strip() if "英文解釋" in row else ""

        level_str = level.replace("第", "").replace("級", "")
        is_sub = "*" in level_str
        level_num = int(level_str.replace("*", ""))

        if level_num == 6 and not is_sub:
            csv_level6.append((word, pinyin, eng))
print(f"  CSV Level 6: {len(csv_level6)} words")

# ========== Generate files ==========
# Mapping: file_id -> xlsx_sheet_index (0-based)
# 準備1=0, 準備2=1, Level1=2, Level2=3, Level3=4, Level4=5, Level5=6
# band_c2 uses CSV Level 6

FILE_CONFIG = {
    "tocfl_novice1": ("xlsx", 0),
    "tocfl_novice2": ("xlsx", 1),
    "tocfl_band_a1": ("xlsx", 2),
    "tocfl_band_a2": ("xlsx", 3),
    "tocfl_band_b1": ("xlsx", 4),
    "tocfl_band_b2": ("xlsx", 5),
    "tocfl_band_c1": ("xlsx", 6),
    "tocfl_band_c2": ("csv", None),
}

print("\nGenerating cards...")
all_results = {}

for file_id, (source, idx) in FILE_CONFIG.items():
    cards = []
    if source == "xlsx":
        tocfl_level = idx + 1  # 1=準備1, 2=準備2, 3=Level1, etc.
        for word, pinyin, pos in xlsx_data[idx]:
            card = build_card(word, pinyin, pos, tocfl_level=tocfl_level)
            cards.append(card)
    elif source == "csv":
        for word, pinyin, eng in csv_level6:
            card = build_card(word, pinyin, tocfl_level=6)
            card["m"] = eng
            cards.append(card)

    # Deduplicate
    seen = set()
    unique = []
    for c in cards:
        if c["t"] not in seen:
            seen.add(c["t"])
            unique.append(c)

    all_results[file_id] = unique
    print(f"  {file_id}: {len(unique)} cards")

# ========== Write JSON files ==========
print("\nWriting JSON files...")
for file_id, cards in all_results.items():
    out_path = f"{OUT_DIR}/{file_id}.json"

    # Read existing file to preserve metadata
    try:
        with open(out_path, "r", encoding="utf-8") as f:
            existing = json.load(f)
        level_tag = existing.get("levelTag", file_id)
    except Exception:
        level_tag = file_id

    output = {
        "id": file_id,
        "standard": "tocfl",
        "levelTag": level_tag,
        "cards": cards,
    }

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, separators=(",", ":"))
    print(f"  Wrote {out_path}")

# ========== Final Summary ==========
print("\n" + "=" * 50)
print("FINAL SUMMARY")
print("=" * 50)
total = 0
for file_id in ["tocfl_novice1", "tocfl_novice2", "tocfl_band_a1", "tocfl_band_a2",
                 "tocfl_band_b1", "tocfl_band_b2", "tocfl_band_c1", "tocfl_band_c2"]:
    n = len(all_results[file_id])
    total += n
    print(f"  {file_id}: {n} cards")
print(f"  {'='*30}")
print(f"  TOTAL: {total} cards")

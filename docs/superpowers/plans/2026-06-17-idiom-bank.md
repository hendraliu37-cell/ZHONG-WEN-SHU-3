# Bank Idiom & Peribahasa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun bank idiom & peribahasa Mandarin **paling lengkap** (≥800 entri) yang berfungsi sebagai paket flashcard SRS sekaligus pengetahuan Guru AI (grounding anti-ngarang + mengajar aktif).

**Architecture:** Satu aset JSON (`idioms.json`) jadi sumber kebenaran, dibangun oleh skrip Python (ekstrak chengyu dari dataset + augment kanonik). Di Flutter: `IdiomBank` service memuat & meng-index aset; paket terdaftar di `manifest.json` (deck SRS); Guru di-ground lewat injeksi prompt sisi-klien di `sendChat` (tanpa redeploy edge function).

**Tech Stack:** Python 3 (build script), Flutter/Dart + Riverpod, `flutter_test`, aset rootBundle JSON.

> **CATATAN GIT:** project `D:\CLAUDE\ZHONG-WEN-SHU-2` **bukan git repo**. Langkah "Commit" diganti **Checkpoint**: jalankan `flutter analyze` + test terkait dan pastikan hijau sebelum lanjut task berikutnya. Tidak ada `git commit`.

> **Spec:** `docs/superpowers/specs/2026-06-17-idiom-bank-design.md`

---

## File Structure

- **Create** `app/assets/packs/build_idioms.py` — skrip pembangun `idioms.json` (ekstrak + augment + validasi). Pola seperti `fix_dict.py`.
- **Create** `app/assets/packs/idioms.json` — output skrip; aset bank (≥800 kartu).
- **Modify** `app/assets/packs/manifest.json` — tambah 1 entri pack `idioms`.
- **Modify** `app/assets/packs/SCHEMA.md` — dokumentasi § "Paket Idiom".
- **Create** `app/lib/models/idiom.dart` — model `Idiom`.
- **Create** `app/lib/services/idiom_bank.dart` — load/index/lookup/detect/contextBlock/randomForTeaching.
- **Modify** `app/lib/state/app_controller.dart` — field `idiomBank`, init load, grounding di `sendChat`, method `learnIdiomWithGuru`, fungsi murni penyusun history.
- **Modify** `app/lib/screens/chat.dart` — tombol "Belajar idiom" di pane Guru.
- **Modify** `app/pubspec.yaml` — (tidak perlu; `assets/packs/` sudah dideklarasikan sebagai direktori).
- **Create** `app/test/idiom_bank_test.dart` — unit test service + fungsi grounding.
- **Create** `app/test/idioms_pack_test.dart` — validasi aset + install.

---

## Task 1: Model `Idiom` + `IdiomBank` service (load/lookup/detect)

**Files:**
- Create: `app/lib/models/idiom.dart`
- Create: `app/lib/services/idiom_bank.dart`
- Test: `app/test/idiom_bank_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// app/test/idiom_bank_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/idiom.dart';
import 'package:zhongwen_shu/services/idiom_bank.dart';

void main() {
  // Fixture: dua idiom, satu chengyu satu peribahasa.
  final fixture = <Map<String, dynamic>>[
    {'s':'一帆风顺','t':'一帆風順','py':'yīfān fēngshùn','zy':'ㄧ ㄈㄢ ㄈㄥ ㄕㄨㄣˋ',
     'm':'berjalan sangat lancar','lit':'satu layar angin mulus','cat':'chengyu',
     'exs':'祝你一帆风顺。','exi':'Semoga semuanya lancar.','tone':1},
    {'s':'入乡随俗','t':'入鄉隨俗','py':'rùxiāng suísú','zy':'ㄖㄨˋ ㄒㄧㄤ ㄙㄨㄟˊ ㄙㄨˊ',
     'm':'di mana bumi dipijak di situ langit dijunjung','lit':'masuk desa ikut adat',
     'cat':'suyu','tone':4},
  ];

  test('load + lookup by 简 and 繁', () {
    final bank = IdiomBank.fromCards(fixture);
    expect(bank.lookup('一帆风顺')!.meaning, 'berjalan sangat lancar');
    expect(bank.lookup('一帆風順')!.category, 'chengyu'); // 繁 juga ter-index
    expect(bank.lookup('不存在'), isNull);
  });

  test('detect finds idioms inside a sentence (longest-match)', () {
    final bank = IdiomBank.fromCards(fixture);
    final hits = bank.detect('我希望这次旅行一帆风顺，谢谢。');
    expect(hits.map((e) => e.simplified), contains('一帆风顺'));
    expect(bank.detect('今天天气很好').isEmpty, isTrue);
  });

  test('contextBlock renders compact grounding string', () {
    final bank = IdiomBank.fromCards(fixture);
    final block = bank.contextBlock([bank.lookup('一帆风顺')!]);
    expect(block, contains('一帆风顺'));
    expect(block, contains('berjalan sangat lancar'));
    expect(block, contains('satu layar angin mulus'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/idiom_bank_test.dart`
Expected: FAIL — `idiom.dart` / `idiom_bank.dart` belum ada (compile error).

- [ ] **Step 3: Write the model**

```dart
// app/lib/models/idiom.dart
/// Satu entri idiom/peribahasa untuk bank bahasa.
class Idiom {
  final String simplified;   // s
  final String traditional;  // t
  final String pinyin;       // py
  final String zhuyin;       // zy
  final String meaning;      // m  (makna/kiasan)
  final String literal;      // lit (arti harfiah)
  final String category;     // cat: 'chengyu' | 'yanyu' | 'suyu'
  final String origin;       // origin (opsional)
  final String exampleS;     // exs
  final String exampleT;     // ext
  final String exampleId;    // exi
  final int tone;

  const Idiom({
    required this.simplified,
    required this.traditional,
    required this.pinyin,
    this.zhuyin = '',
    required this.meaning,
    this.literal = '',
    required this.category,
    this.origin = '',
    this.exampleS = '',
    this.exampleT = '',
    this.exampleId = '',
    this.tone = 1,
  });

  factory Idiom.fromJson(Map<String, dynamic> j) => Idiom(
        simplified: (j['s'] ?? '') as String,
        traditional: (j['t'] ?? j['s'] ?? '') as String,
        pinyin: (j['py'] ?? '') as String,
        zhuyin: (j['zy'] ?? '') as String,
        meaning: (j['m'] ?? '') as String,
        literal: (j['lit'] ?? '') as String,
        category: (j['cat'] ?? 'chengyu') as String,
        origin: (j['origin'] ?? '') as String,
        exampleS: (j['exs'] ?? '') as String,
        exampleT: (j['ext'] ?? '') as String,
        exampleId: (j['exi'] ?? '') as String,
        tone: (j['tone'] ?? 1) as int,
      );
}
```

- [ ] **Step 4: Write the service**

```dart
// app/lib/services/idiom_bank.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import '../models/idiom.dart';

/// Bank idiom & peribahasa. Sumber tunggal yang sama dipakai sebagai paket
/// flashcard (lewat manifest) DAN pengetahuan Guru (grounding + mengajar).
/// Batas bersih: [load] sekali, lalu [lookup]/[detect]/[contextBlock].
class IdiomBank {
  final Map<String, Idiom> _byHanzi = {};
  final List<Idiom> _all = [];
  bool _loaded = false;
  final math.Random _rng = math.Random();

  IdiomBank();

  /// Konstruksi langsung dari list map (dipakai test & internal).
  factory IdiomBank.fromCards(List<Map<String, dynamic>> cards) {
    final b = IdiomBank();
    b._ingest(cards.map(Idiom.fromJson));
    b._loaded = true;
    return b;
  }

  void _ingest(Iterable<Idiom> items) {
    for (final it in items) {
      _all.add(it);
      if (it.simplified.isNotEmpty) _byHanzi[it.simplified] = it;
      if (it.traditional.isNotEmpty) _byHanzi[it.traditional] = it;
    }
  }

  /// Muat aset sekali (idempotent, aman bila aset tak ada).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/packs/idioms.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cards = (data['cards'] as List).cast<Map<String, dynamic>>();
      _ingest(cards.map(Idiom.fromJson));
    } catch (_) {
      // aset belum ada / gagal → bank kosong, fitur lain tetap jalan.
    }
    _loaded = true;
  }

  Idiom? lookup(String hanzi) => _byHanzi[hanzi.trim()];

  int get count => _all.length;

  static final RegExp _cjk = RegExp(r'[一-鿿㐀-䶿]');
  static const int _maxLen = 8; // peribahasa bisa panjang

  /// Idiom yang muncul dalam [text] (longest-match, tanpa tumpang tindih).
  List<Idiom> detect(String text) {
    final out = <Idiom>[];
    var i = 0;
    while (i < text.length) {
      if (!_cjk.hasMatch(text[i])) { i++; continue; }
      Idiom? hit; var len = 0;
      final maxLen = math.min(_maxLen, text.length - i);
      for (var l = maxLen; l >= 2; l--) {
        final cand = text.substring(i, i + l);
        final e = _byHanzi[cand];
        if (e != null) { hit = e; len = l; break; }
      }
      if (hit != null) { out.add(hit); i += len; } else { i++; }
    }
    return out;
  }

  /// Pilih satu idiom untuk diajarkan (opsional per kategori).
  Idiom? randomForTeaching({String? cat}) {
    final pool = cat == null ? _all : _all.where((e) => e.category == cat).toList();
    if (pool.isEmpty) return null;
    return pool[_rng.nextInt(pool.length)];
  }

  /// Blok ringkas untuk disuntik ke prompt LLM.
  String contextBlock(List<Idiom> items) {
    final label = {'chengyu': '成语', 'yanyu': '谚语', 'suyu': '俗语'};
    return items.map((e) {
      final parts = <String>['${label[e.category] ?? ''} ${e.simplified} (${e.pinyin})'];
      if (e.literal.isNotEmpty) parts.add('harfiah: "${e.literal}"');
      parts.add('makna: ${e.meaning}');
      if (e.exampleS.isNotEmpty) parts.add('contoh: ${e.exampleS}');
      if (e.origin.isNotEmpty) parts.add('asal: ${e.origin}');
      return parts.join('; ');
    }).join('\n');
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd app && flutter test test/idiom_bank_test.dart`
Expected: PASS (3 test).

- [ ] **Step 6: Checkpoint**

Run: `cd app && flutter analyze`
Expected: No issues. (Tidak ada git commit — project bukan repo.)

---

## Task 2: `build_idioms.py` — ekstraksi chengyu dari dataset

**Files:**
- Create: `app/assets/packs/build_idioms.py`

Skrip ini mengekstrak chengyu dari 17 file pack, menyaring non-idiom, dan **mencetak ringkasan** (belum menulis idioms.json — itu Task 3). Memastikan filter benar dulu.

- [ ] **Step 1: Tulis kerangka ekstraksi + daftar-kecuali**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bangun idioms.json: ekstrak chengyu dari dataset + augment kanonik."""
import json, glob, os, sys, re
sys.stdout.reconfigure(encoding='utf-8')
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Non-idiom 4-karakter yang harus DIBUANG dari hasil ekstraksi.
EXCLUDE = {
    "公共汽车","高速公路","电子邮件","百科全书","一般来说","另一方面",
    "这就是说","成千上万","绝大多数","不怎么样","不一会儿","不好意思",
    "西班牙语","阿拉伯语","中华民族","长期以来",
}
def is_lang_name(s):  # …语 / …文 (nama bahasa/tulisan)
    return s.endswith("语") or s.endswith("文")

def extract():
    seen = {}
    for f in sorted(glob.glob("hsk*.json") + glob.glob("tocfl_*.json")):
        d = json.load(open(f, encoding="utf-8"))
        for c in d.get("cards", []):
            s = c.get("s") or ""
            if len(s) == 4 and s not in EXCLUDE and not is_lang_name(s):
                # kandidat chengyu — simpan field yang ada
                seen.setdefault(s, {
                    "s": s, "t": c.get("t") or s, "py": c.get("py") or "",
                    "zy": c.get("zy") or "", "m": c.get("m") or "",
                    "exs": c.get("exs") or "", "ext": c.get("ext") or "",
                    "exi": c.get("exi") or "", "tone": c.get("tone", 1),
                    "hsk": c.get("hsk"),
                })
    return seen

if __name__ == "__main__":
    ex = extract()
    print("chengyu terekstrak:", len(ex))
    for s in list(ex)[:20]:
        print(" ", s, "->", ex[s]["m"])
```

- [ ] **Step 2: Jalankan & verifikasi filter**

Run: `cd app/assets/packs && python build_idioms.py`
Expected: cetak "chengyu terekstrak: ~400" dan TIDAK memuat 公共汽车/高速公路/…语. Bila ada non-idiom lolos, tambahkan ke `EXCLUDE` dan ulangi.

- [ ] **Step 3: Checkpoint**

Tidak ada test framework untuk skrip ini; verifikasi manual output di Step 2 cukup. Lanjut.

---

## Task 3: `build_idioms.py` — augment kanonik + tulis `idioms.json`

**Files:**
- Modify: `app/assets/packs/build_idioms.py`
- Create (via run): `app/assets/packs/idioms.json`
- Create: `app/test/idioms_pack_test.dart`

**Tujuan cakupan "paling lengkap":** total ≥ 800 entri. Sumber augment = peta kanonik di skrip. **Akurasi mutlak** — hanya idiom mapan; entri ragu diverifikasi web (WebSearch) sebelum dimasukkan. Setiap entri augment WAJIB: `s,t,py,m,lit,cat`; `zy` diturunkan dari `py`; `tone` dari `py`.

- [ ] **Step 1: Tambah helper zhuyin + tone + peta augment**

Reuse konverter zhuyin yang sudah ada: import dari `generate_hsk.py` (di folder sama).

```python
# tambahkan di build_idioms.py
import importlib.util
def _load_zhuyin():
    spec = importlib.util.spec_from_file_location("genhsk", "generate_hsk.py")
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m.pinyin_to_zhuyin
pinyin_to_zhuyin = _load_zhuyin()

TONE_MARKS = {1:"āēīōūǖ",2:"áéíóúǘ",3:"ǎěǐǒǔǚ",4:"àèìòùǜ"}
def first_tone(py):
    seg = (py.split() or [""])[0]
    for ch in seg:
        for t, marks in TONE_MARKS.items():
            if ch in marks: return t
    return 5

# Peta augment kanonik. Kunci = 简体. Nilai = dict {t, py, lit, m, cat, exs, exi}.
# cat: 'chengyu' | 'yanyu' (谚语) | 'suyu' (俗语).
# CONTOH BENIH (perluas ke ratusan; verifikasi web bila ragu):
AUG = {
  "入乡随俗": {"t":"入鄉隨俗","py":"rùxiāng suísú","cat":"suyu",
    "lit":"masuk desa ikut adat","m":"di mana bumi dipijak di situ langit dijunjung",
    "exs":"到了国外要入乡随俗。","exi":"Di luar negeri harus ikut adat setempat."},
  "熟能生巧": {"t":"熟能生巧","py":"shú néng shēng qiǎo","cat":"chengyu",
    "lit":"mahir bisa melahirkan kepiawaian","m":"bisa karena terbiasa; latihan membuat mahir",
    "exs":"多练习，熟能生巧。","exi":"Banyak latihan, bisa karena terbiasa."},
  "活到老学到老": {"t":"活到老學到老","py":"huó dào lǎo xué dào lǎo","cat":"yanyu",
    "lit":"hidup sampai tua belajar sampai tua","m":"belajar sepanjang hayat",
    "exs":"活到老学到老，他六十岁还在上课。","exi":"Belajar seumur hidup; usia 60 ia masih kuliah."},
  "一分耕耘一分收获": {"t":"一分耕耘一分收穫","py":"yìfēn gēngyún yìfēn shōuhuò","cat":"yanyu",
    "lit":"sebagian membajak sebagian panen","m":"ada usaha ada hasil",
    "exs":"一分耕耘一分收获，努力不会白费。","exi":"Ada usaha ada hasil; kerja keras tak sia-sia."},
  "画蛇添足": {"t":"畫蛇添足","py":"huàshé tiānzú","cat":"chengyu",
    "lit":"menggambar ular menambah kaki","m":"melakukan hal berlebihan yang justru merusak",
    "exs":"这样改简直是画蛇添足。","exi":"Mengubahnya begitu malah merusak."},
  # … LANJUTKAN sampai total bank ≥ 800 (gabungan ekstrak + augment).
}
```

- [ ] **Step 2: Gabung, lengkapi field turunan, tulis idioms.json**

```python
def build():
    cards = []
    seen = set()
    # (a) hasil ekstraksi dataset (chengyu)
    for s, c in extract().items():
        c["cat"] = "chengyu"
        c.setdefault("lit", "")
        if not c.get("zy"): c["zy"] = pinyin_to_zhuyin(c["py"])
        c["tone"] = first_tone(c["py"])
        cards.append(c); seen.add(s)
    # (b) augment kanonik (skip jika sudah ada dari ekstraksi)
    for s, a in AUG.items():
        if s in seen: continue
        cards.append({
            "s": s, "t": a["t"], "py": a["py"],
            "zy": pinyin_to_zhuyin(a["py"]),
            "m": a["m"], "lit": a.get("lit",""), "cat": a["cat"],
            "origin": a.get("origin",""),
            "exs": a.get("exs",""), "ext": a.get("ext",""), "exi": a.get("exi",""),
            "tone": first_tone(a["py"]),
        })
        seen.add(s)
    cards.sort(key=lambda c: c["py"])
    out = {"id":"idioms","name":"Idiom & Peribahasa","standard":"idiom",
           "levelTag":"Idiom","cards":cards}
    with open("idioms.json","w",encoding="utf-8") as f:
        f.write('{"id":"idioms","name":"Idiom & Peribahasa","standard":"idiom","levelTag":"Idiom","cards":[\n')
        for idx,c in enumerate(cards):
            f.write(json.dumps(c,ensure_ascii=False,separators=(",",":")))
            f.write(",\n" if idx<len(cards)-1 else "\n")
        f.write("]}\n")
    print("TOTAL bank:", len(cards))

# ganti blok __main__ jadi: build()
```

- [ ] **Step 3: Jalankan build**

Run: `cd app/assets/packs && python build_idioms.py`
Expected: "TOTAL bank: ≥ 800". File `idioms.json` JSON valid.

- [ ] **Step 4: Tulis test validasi aset**

```dart
// app/test/idioms_pack_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idioms.json valid, lengkap, field wajib & kategori benar', () {
    final raw = File('assets/packs/idioms.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    expect(data['standard'], 'idiom');
    final cards = (data['cards'] as List).cast<Map<String, dynamic>>();
    expect(cards.length, greaterThanOrEqualTo(800));
    const cats = {'chengyu', 'yanyu', 'suyu'};
    for (final c in cards) {
      for (final k in ['s','t','py','zy','m','cat','tone']) {
        expect((c[k]?.toString() ?? '').isNotEmpty, isTrue, reason: '$k kosong di ${c['s']}');
      }
      expect(cats.contains(c['cat']), isTrue, reason: 'cat tak valid di ${c['s']}');
    }
    // tidak ada non-idiom yang lolos
    final hanzi = cards.map((c) => c['s']).toSet();
    expect(hanzi.contains('公共汽车'), isFalse);
    expect(hanzi.contains('高速公路'), isFalse);
  });
}
```

- [ ] **Step 5: Run validasi**

Run: `cd app && flutter test test/idioms_pack_test.dart`
Expected: PASS. Jika gagal (mis. <800 atau field kosong), perluas `AUG` / perbaiki data, jalankan build ulang.

- [ ] **Step 6: Dokumentasi + Checkpoint**

Tambah § "Paket Idiom" ke `app/assets/packs/SCHEMA.md` (jelaskan field `lit`/`cat`/`origin`, dan bahwa `idioms.json` dibangun oleh `build_idioms.py`).
Run: `cd app && flutter analyze` → No issues.

---

## Task 4: Daftarkan paket di manifest + dukung `standard:"idiom"`

**Files:**
- Modify: `app/assets/packs/manifest.json`
- Modify: `app/lib/state/app_controller.dart` (audit `installPack` / pemakaian `standard`)
- Test: `app/test/idioms_pack_test.dart` (tambah test install)

- [ ] **Step 1: Tambah entri manifest**

Tambahkan elemen ini di akhir array `manifest.json` (sebelum `]`):

```json
,
  { "id": "idioms", "name": "Idiom & Peribahasa 成语·谚语",
    "meta": "成语 + 谚语/俗语 · 简+繁 · pinyin+注音",
    "standard": "idiom", "levelTag": "Idiom", "asset": "assets/packs/idioms.json" }
```

- [ ] **Step 2: Audit asumsi `standard`**

Run: `cd app && grep -rn "standard ==" lib/ ; grep -rn "'hsk'\|'tocfl'" lib/`
Periksa setiap percabangan yang membandingkan `standard` (badge/warna/zhuyin/track). Untuk nilai `'idiom'`: pastikan jatuh ke cabang default yang netral (jangan crash, jangan paksa zhuyin off bila track traditional). Tidak perlu UI khusus — cukup tidak pecah.

- [ ] **Step 3: Tulis test install**

Tambahkan ke `app/test/idioms_pack_test.dart`:

```dart
  test('paket idioms terdaftar di manifest', () {
    final raw = File('assets/packs/manifest.json').readAsStringSync();
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final pack = list.firstWhere((p) => p['id'] == 'idioms');
    expect(pack['standard'], 'idiom');
    expect(pack['asset'], 'assets/packs/idioms.json');
  });
```

- [ ] **Step 4: Run + Checkpoint**

Run: `cd app && flutter test test/idioms_pack_test.dart && flutter analyze`
Expected: PASS, No issues.

---

## Task 5: Guru grounding di `sendChat` (fungsi murni + wiring)

**Files:**
- Modify: `app/lib/state/app_controller.dart`
- Test: `app/test/idiom_bank_test.dart` (tambah test fungsi murni)

- [ ] **Step 1: Tulis test fungsi penyusun history**

Tambahkan ke `app/test/idiom_bank_test.dart`:

```dart
  test('groundedHistory injects context only when idiom present', () {
    final bank = IdiomBank.fromCards(fixture);
    final base = [{'role':'user','content':'apa arti 一帆风顺?'}];
    final grounded = buildGroundedHistory(base, bank);
    expect(grounded.last['content'], contains('一帆风顺'));
    expect(grounded.last['content'], contains('Bank idiom'));

    final base2 = [{'role':'user','content':'halo guru'}];
    final same = buildGroundedHistory(base2, bank);
    expect(same.last['content'], 'halo guru'); // tak ada idiom → tak diubah
  });
```

Tambahkan import di atas test: `import 'package:zhongwen_shu/state/app_controller.dart' show buildGroundedHistory;`

- [ ] **Step 2: Run test (gagal)**

Run: `cd app && flutter test test/idiom_bank_test.dart`
Expected: FAIL — `buildGroundedHistory` belum ada.

- [ ] **Step 3: Implement fungsi murni (top-level di app_controller.dart)**

```dart
/// Mengembalikan salinan [history] di mana pesan user TERAKHIR diperkaya blok
/// konteks bank idiom bila ada idiom terdeteksi. Murni & teruji (no I/O).
List<Map<String, String>> buildGroundedHistory(
    List<Map<String, String>> history, IdiomBank bank) {
  if (history.isEmpty) return history;
  final lastUser = history.lastIndexWhere((m) => m['role'] == 'user');
  if (lastUser < 0) return history;
  final content = history[lastUser]['content'] ?? '';
  final hits = bank.detect(content);
  if (hits.isEmpty) return history;
  final block = bank.contextBlock(hits);
  final copy = history.map((m) => Map<String, String>.from(m)).toList();
  copy[lastUser]['content'] =
      '$content\n\n[Bank idiom — jelaskan dari data ini, jangan mengarang:\n$block]';
  return copy;
}
```

Pastikan `import '../services/idiom_bank.dart';` ada di app_controller.dart.

- [ ] **Step 4: Wire ke sendChat**

Di `app_controller.dart` `sendChat()`, ganti baris pemanggilan LLM:

```dart
    if (llm.enabled && signedIn) {
      reply = await llm.chat(buildGroundedHistory(_llmHistory(), idiomBank), track: track);
    }
```

Tambah field & init di kelas controller:
```dart
  final IdiomBank idiomBank = IdiomBank();
```
Dan di rutin inisialisasi (tempat seed/manifest dimuat), panggil sekali (non-blocking, aman bila aset kosong):
```dart
    idiomBank.load();
```

- [ ] **Step 5: Run test (lulus)**

Run: `cd app && flutter test test/idiom_bank_test.dart`
Expected: PASS (semua test bank + grounding).

- [ ] **Step 6: Checkpoint**

Run: `cd app && flutter analyze` → No issues.

---

## Task 6: Guru mengajar aktif (`learnIdiomWithGuru` + tombol UI)

**Files:**
- Modify: `app/lib/state/app_controller.dart`
- Modify: `app/lib/screens/chat.dart`

- [ ] **Step 1: Tambah method di controller**

```dart
  /// Minta Guru mengajarkan satu idiom dari bank (akurat karena entri disuntik).
  Future<void> learnIdiomWithGuru({String? cat}) async {
    final it = idiomBank.randomForTeaching(cat: cat);
    if (it == null) return;
    final block = idiomBank.contextBlock([it]);
    // Tampilan ringkas ke user; payload ke LLM membawa blok lengkap.
    messages = [...messages, ChatMsg('me', 'Ajari aku idiom ${it.simplified}')];
    tutorTyping = true;
    notifyListeners();
    String? reply;
    if (llm.enabled && signedIn) {
      final hist = [
        ..._llmHistory(),
        {'role': 'user', 'content':
          'Ajari aku idiom ini: $block. Jelaskan maknanya, asal-usul singkat, '
          'beri 1 contoh kalimat baru, lalu beri aku 1 soal singkat.'},
      ];
      reply = await llm.chat(hist, track: track);
    }
    reply ??= 'Idiom ${it.simplified} (${it.pinyin}) — ${it.meaning}.'
        '${it.literal.isNotEmpty ? ' Harfiah: ${it.literal}.' : ''}';
    tutorTyping = false;
    messages = [...messages, ChatMsg('t', reply)];
    notifyListeners();
  }
```

> Catatan: `_llmHistory()` private — `learnIdiomWithGuru` ada di kelas yang sama, jadi boleh akses. Tidak perlu grounding ganda (blok sudah disuntik manual di sini).

- [ ] **Step 2: Tambah tombol di pane Guru**

Di `chat.dart`, pada segmen Guru (cari tempat input chat privat), tambahkan tombol kecil (ikon lineart, TANPA emoji — sesuai aturan desain) yang memanggil `controller.learnIdiomWithGuru()`. Contoh penempatan di atas daftar pesan atau dekat input:

```dart
TextButton(
  onPressed: c.tutorTyping ? null : () => c.learnIdiomWithGuru(),
  child: const Text('Belajar idiom'),
),
```

(Ikuti pola widget & gaya yang sudah ada di file; jangan menambah emoji.)

- [ ] **Step 3: Verifikasi manual ringan**

Run: `cd app && flutter analyze`
Expected: No issues. (Alur Guru nyata butuh secret LLM; fallback canned sudah ditangani sehingga tetap aman tanpa jaringan.)

- [ ] **Step 4: Checkpoint** — lanjut ke regresi.

---

## Task 7: Regresi penuh

**Files:** (tidak ada perubahan kode; gerbang kualitas)

- [ ] **Step 1: Analyze**

Run: `cd app && flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Seluruh test**

Run: `cd app && flutter test`
Expected: All tests passed — 39 test lama + test baru (idiom_bank + idioms_pack) hijau.

- [ ] **Step 3: (Opsional) build Windows**

Run: `cd app && flutter build windows --debug`
Expected: SUKSES. (Matikan dulu instance app yang sedang jalan — LNK1168.)

- [ ] **Step 4: Update memori project** — catat sesi: bank idiom ≥800 entri (ekstrak+augment), IdiomBank service, grounding + mengajar Guru, paket `idioms` di manifest, jumlah test akhir.

---

## Self-Review (diisi penulis plan)

- **Spec coverage:** Data bank (T2–T3) ✓; flashcard pack/manifest (T4) ✓; IdiomBank service (T1) ✓; grounding (T5) ✓; mengajar aktif (T6) ✓; testing (T1,T3,T4,T5,T7) ✓; "paling lengkap" ≥800 ditegakkan oleh test T3-Step4 ✓.
- **Placeholder scan:** `AUG` sengaja benih + instruksi eksplisit "lanjutkan sampai ≥800"; ini konten yang diperluas saat eksekusi, bukan placeholder kode. Tidak ada TODO/TBD pada langkah kode.
- **Type consistency:** `Idiom`/`IdiomBank.fromCards/load/lookup/detect/contextBlock/randomForTeaching`, `buildGroundedHistory`, `learnIdiomWithGuru` konsisten dipakai antar-task.
- **Git:** langkah commit diganti Checkpoint (project bukan repo).

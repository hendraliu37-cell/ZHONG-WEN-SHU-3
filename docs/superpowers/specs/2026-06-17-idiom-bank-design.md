# Bank Idiom & Peribahasa (成语·谚语) — Design

**Tanggal:** 2026-06-17
**Status:** disetujui user (brainstorm sesi-7)
**Konteks:** lanjutan audit kamus. Dataset punya 22.692 kartu; ~606 entri 4-karakter
(kandidat chengyu, tercampur kata biasa); **0 entri ≥5 karakter** → peribahasa
panjang (谚语/俗语) praktis tidak ada di data.

## Tujuan

Membangun **bank idiom & peribahasa yang selengkap mungkin** yang berfungsi
sebagai:
1. **Paket flashcard** (deck di `manifest.json`) — dipelajari via FSRS seperti
   paket HSK/TOCFL.
2. **Pengetahuan Guru AI** — dua peran:
   - **Grounding (anti-ngarang):** saat user menyebut/menanyakan idiom, Guru
     dijelaskan dari entri bank yang akurat, bukan mengarang.
   - **Mengajar aktif:** Guru bisa memilih idiom dari bank, menjelaskan, memberi
     contoh, lalu menguji user.

> **Prinsip akurasi mutlak** (warisan `SCHEMA.md`): ini app belajar bahasa.
> Idiom/arti yang salah = bug serius. Augmentasi hanya dari pengetahuan kanonik
> yang mapan; yang ragu diverifikasi web. Jangan mengarang idiom/arti.

## Keputusan yang sudah dikunci (dari brainstorm)

- **Sumber isi:** ekstrak chengyu dari dataset **+** augment idiom & peribahasa
  populer dari luar (pengetahuan kanonik + verifikasi web).
- **Bentuk:** paket flashcard **dan** pengetahuan Guru.
- **Peran Guru:** grounding **dan** mengajar aktif.
- **Wiring Guru:** **Pendekatan A** — injeksi prompt sisi-klien lewat `llm.chat`
  yang sudah ada (tanpa redeploy edge function). Grounding grup (server-side)
  ditunda ke fase berikutnya.
- **Cakupan:** **paling lengkap.** Target ≥ 800 idiom (semua chengyu valid dari
  dataset + augmentasi besar chengyu umum + peribahasa 谚语/俗语 mapan). Bukan
  subset terkurasi kecil.

## Arsitektur & komponen

### 1. Data — satu sumber kebenaran

Aset baru: `app/assets/packs/idioms.json`. Amplop sama dgn pack lain:
```json
{ "id":"idioms", "name":"Idiom & Peribahasa", "standard":"idiom",
  "levelTag":"Idiom", "cards":[ ... ] }
```

Skema kartu = field `VocabEntry` yang ada **+ field opsional** (loader
`VocabEntry.fromJson` mengabaikan key tak dikenal — aman; IdiomBank yang membaca
field tambahan):

| key | wajib | arti |
|-----|-------|------|
| `s` | ✅ | 简体 idiom |
| `t` | ✅ | 繁體 idiom |
| `py` | ✅ | 拼音 (tone marks) |
| `zy` | ✅ | 注音 |
| `m` | ✅ | **makna/kiasan** ringkas (Indonesia) — yang tampil di flashcard |
| `tone` | ✅ | nada suku kata pertama (dihitung dari pinyin) |
| `lit` | ⬜ | arti **harfiah** (Indonesia) |
| `cat` | ✅ | `chengyu` \| `yanyu` (谚语) \| `suyu` (俗语) |
| `origin` | ⬜ | asal-usul singkat (opsional) |
| `exs`/`ext`/`exi` | ⬜ | contoh kalimat 简/繁/terjemahan |
| `hsk` | ⬜ | level HSK bila entri berasal dari band HSK |

Isi dibangun lewat skrip **`app/assets/packs/build_idioms.py`** (pola seperti
`fix_dict.py`):
- **Ekstrak:** iterasi 606 entri 4-karakter di semua pack; **buang non-idiom**
  via daftar-kecuali + heuristik:
  - akhiran nama bahasa/tulisan: `…语`, `…文` (西班牙语, 阿拉伯语).
  - benda majemuk modern (公共汽车, 高速公路, 电子邮件, 百科全书) — daftar eksplisit.
  - frasa fungsional/numerik (一般来说, 另一方面, 这就是说, 成千上万, 绝大多数,
    不怎么样) — daftar eksplisit.
  - Sisanya (chengyu asli) → masuk, dilengkapi `lit`, `cat="chengyu"`, contoh.
- **Augment:** tambah chengyu umum penting yang belum ada + peribahasa 谚语/俗语
  mapan, dari peta kanonik di skrip (hanzi → {py, lit, makna, cat, contoh}).
  Verifikasi web untuk entri yang ragu sebelum dimasukkan.
- **Tone** dihitung deterministik dari pinyin (fungsi sama seperti fix_dict.py).
- Output JSON valid UTF-8; dicatat di `SCHEMA.md` (§ baru "Paket Idiom").

### 2. Paket flashcard

Tambah satu entri di `manifest.json`:
```json
{ "id":"idioms", "name":"Idiom & Peribahasa 成语·谚语",
  "meta":"成语 + 谚语/俗语 · 简+繁 · pinyin+注音",
  "standard":"idiom", "levelTag":"Idiom", "asset":"assets/packs/idioms.json" }
```
Pastikan jalur pack-install (`installPack`) & UI Library menerima
`standard:"idiom"`. Audit titik yang berasumsi `'hsk'|'tocfl'` (mis. badge/warna,
filter track, toggle zhuyin); tangani `'idiom'` (fallback ke perilaku netral /
`'mixed'`) tanpa memecah UI. Flashcard menampilkan idiom→`m`; sisi belakang
boleh menampilkan `lit` + contoh.

### 3. `lib/services/idiom_bank.dart`

Service murni, batas bersih (load → tanya):
- `Future<void> load()` — baca `assets/packs/idioms.json` sekali (lazy, idempotent),
  bangun index `Map<String, Idiom>` by 简 dan 繁.
- `Idiom? lookup(String hanzi)`
- `List<Idiom> detect(String text)` — longest-match scan (pola sama `DictionaryService.segment`)
  → idiom yang muncul dalam teks.
- `Idiom? randomForTeaching({String? cat})` — pilih acak (opsional per kategori).
- `String contextBlock(List<Idiom> items)` — blok ringkas untuk prompt LLM, mis.:
  `成语 一帆风顺 (yīfān fēngshùn) — harfiah: "satu layar angin mulus"; makna:
  "berjalan sangat lancar"; contoh: 祝你一帆风顺。`
- Model `Idiom` (s,t,py,zy,m,lit,cat,origin,exs,ext,exi,tone).

### 4. Guru grounding (anti-ngarang)

Di `app_controller.sendChat()`, sebelum memanggil `llm.chat(_llmHistory())`:
- `final hits = idiomBank.detect(txt);`
- Jika `hits` tak kosong, kirim history dengan pesan user terakhir **diperkaya**
  blok konteks (client-side; teks yang ditampilkan di UI tetap asli). Caranya:
  bangun salinan history di mana `content` pesan user terakhir = `txt` +
  `"\n\n[Bank idiom — pakai data ini, jangan mengarang:\n" + contextBlock(hits) + "]"`.
- Tanpa perubahan edge function. Grounding hanya di **chat privat** dulu.

### 5. Guru mengajar aktif

Di Chat·Guru, aksi "Belajar idiom":
- `final it = idiomBank.randomForTeaching();`
- Susun pesan user terstruktur (dikirim lewat `sendChat` path), mis.:
  `"Ajari aku idiom ini: <contextBlock([it])>. Jelaskan maknanya, asal-usul
  singkat, beri 1 contoh kalimat baru, lalu beri aku 1 soal singkat."`
- Karena entri disuntik, penjelasan akurat. UI: tombol di pane Guru; teks yang
  tampil ke user boleh diringkas ("Ajari aku idiom 一帆风顺") sementara payload
  ke LLM membawa blok lengkap.

### 6. Wiring controller

- Field `IdiomBank idiomBank` di controller; `idiomBank.load()` dipanggil saat
  init (setelah seed load), non-blocking, aman bila aset belum ada (try/catch).
- Method baru: `learnIdiomWithGuru()`.

## Testing

- **Unit `idiom_bank_test.dart`:** load dari fixture kecil; `detect` longest-match
  (idiom di tengah kalimat, dua idiom, tidak ada idiom); `lookup` 简↔繁;
  `contextBlock` format; `randomForTeaching` mengembalikan entri valid.
- **Build validation** (`test/idioms_pack_test.dart` atau cek di build_idioms.py):
  JSON valid; setiap kartu punya `s,t,py,zy,m,cat,tone`; `cat` ∈ {chengyu,yanyu,suyu};
  tidak ada entri di daftar-kecuali; tone cocok pinyin.
- **Grounding assembly:** fungsi penyusun history-yang-diperkaya diuji murni
  (idiom terdeteksi → blok tersuntik; tidak ada → history apa adanya).
- **Pack install:** extend pola `pack_install_test.dart` → paket `idioms`
  ter-install ke library.
- **Regresi:** 39 test lama tetap hijau; `flutter analyze` bersih.

## Yang TIDAK termasuk (YAGNI / fase berikutnya)

- Grounding di grup (group-guru server-side) — ditunda.
- Param `context` di edge function (Pendekatan B) — ditunda.
- Pelacakan "idiom sudah dipelajari" khusus (pakai SRS deck biasa dulu).
- Audio/TTS khusus idiom (deck biasa sudah pakai TTS yang ada).

## Risiko & catatan

- **Akurasi augmentasi:** sumber = pengetahuan kanonik; entri ragu diverifikasi
  web. Lebih baik sedikit-tapi-benar daripada banyak-tapi-salah, namun target
  tetap "paling lengkap" untuk idiom yang mapan.
- **`standard:"idiom"` baru** bisa menyentuh asumsi UI lama → audit eksplisit di
  langkah pack.
- Project **bukan git repo** → spec tidak di-commit (sama seperti spec grup).

# Paket Materi — Skema & Instruksi Pengisian (untuk OpenCode)

Folder ini berisi paket kosakata siap-unduh untuk app **ZHONGWEN SHU**.
Tugasmu (OpenCode): **isi array `cards` di tiap file** dengan kosakata resmi
level tersebut. Struktur file & daftar level sudah disiapkan — jangan ubah
nama file / `id` / `levelTag`, cukup isi `cards`.

> ⚠️ **Akurasi mutlak.** Ini app belajar bahasa. JANGAN mengarang kata atau
> level. Pakai daftar resmi (HSK 3.0 / TOCFL 8000 詞) sebagai sumber. Kata yang
> salah level atau arti yang salah = bug serius.

---

## 1. Format satu kartu (JSON)

Setiap elemen `cards` adalah objek dengan field berikut (key singkat):

| key    | wajib | arti | contoh |
|--------|-------|------|--------|
| `s`    | ✅ | 简体 (simplified) | `"商店"` |
| `t`    | ✅ | 繁體 (traditional) — hasil konversi dari `s` | `"商店"` |
| `py`   | ✅ | 拼音 dengan tanda nada (tone marks) | `"shāngdiàn"` |
| `zy`   | ✅ | 注音 (zhuyin/bopomofo), spasi antar suku kata | `"ㄕㄤ ㄉㄧㄢˋ"` |
| `m`    | ✅ | arti dalam **Bahasa Indonesia** | `"toko"` |
| `tone` | ✅ | nada suku kata **pertama** (1–4, atau 5 = netral) | `1` |
| `exs`  | ⬜ | contoh kalimat 简体 | `"我去商店买东西。"` |
| `ext`  | ⬜ | contoh kalimat 繁體 | `"我去商店買東西。"` |
| `exi`  | ⬜ | terjemahan contoh (Indonesia) | `"Saya pergi ke toko."` |
| `hsk`  | ⬜ | nomor level HSK (1–9) — isi di paket HSK | `3` |
| `tocfl`| ⬜ | nomor level TOCFL (lihat §3) — isi di paket TOCFL | `1` |

Contoh kartu lengkap:

```json
{"s":"商店","t":"商店","py":"shāngdiàn","zy":"ㄕㄤ ㄉㄧㄢˋ","m":"toko","exs":"我去商店买东西。","ext":"我去商店買東西。","exi":"Saya pergi ke toko membeli barang.","tone":1,"hsk":3}
```

Aturan:
- `s`, `t`, `py`, `zy`, `m`, `tone` **wajib** ada di tiap kartu.
- `t` = konversi simplified→traditional yang benar (mis. 国→國, 学→學). Kalau
  karakter sama di kedua standar, `t` = `s`.
- `zy` = konversi dari `py` (deterministik). Tanda nada zhuyin: 1=tanpa tanda,
  2=ˊ, 3=ˇ, 4=ˋ, netral=˙ (di depan suku kata netral).
- `tone` mengikuti nada suku kata **pertama** headword.
- `exs`/`ext`/`exi` opsional tapi **sangat dianjurkan** (dipakai untuk latihan).
- File hanya dibaca lewat array `cards`. Field `_fill` diabaikan app — boleh
  dihapus saat sudah terisi.

Validasi cepat: tiap file harus **JSON valid** (UTF-8), array `cards` berisi
objek-objek di atas.

---

## 2. Paket HSK (HSK 3.0 / 2021) — `hsk1.json` … `hsk9.json`

Isi tiap paket dengan kosakata **baru** di level itu (sesuai daftar resmi
HSK 3.0). Jumlah kata per level (rujukan — verifikasi ke daftar resmi):

| File | Level | ± jumlah kata baru |
|------|-------|--------------------|
| `hsk1.json` | HSK 1 | 500 |
| `hsk2.json` | HSK 2 | 772 |
| `hsk3.json` | HSK 3 | 973 |
| `hsk4.json` | HSK 4 | 1000 |
| `hsk5.json` | HSK 5 | 1071 |
| `hsk6.json` | HSK 6 | 1140 |
| `hsk7.json` | HSK 7 | bagian dari band 7–9 (total 5636) |
| `hsk8.json` | HSK 8 | bagian dari band 7–9 |
| `hsk9.json` | HSK 9 | bagian dari band 7–9 |

> HSK 7–9 secara resmi satu band gabungan (5636 kata). Bagi ke `hsk7/8/9`
> mengikuti sublevel daftar resmi bila tersedia; kalau tidak, bagi rata
> berurutan. `hsk1.json` & `hsk2.json` sudah berisi benih — lengkapi.
> Set `"hsk"` = nomor level di tiap kartu.

---

## 3. Paket TOCFL (daftar 8000 詞) — `tocfl_*.json`

| File | Level (中文) | Band | `tocfl` |
|------|--------------|------|---------|
| `tocfl_novice1.json` | 準備級一級 | Novice 1 | 1 |
| `tocfl_novice2.json` | 準備級二級 | Novice 2 | 2 |
| `tocfl_band_a1.json` | 入門級 | Band A · Level 1 | 3 |
| `tocfl_band_a2.json` | 基礎級 | Band A · Level 2 | 4 |
| `tocfl_band_b1.json` | 進階級 | Band B · Level 3 | 5 |
| `tocfl_band_b2.json` | 高階級 | Band B · Level 4 | 6 |
| `tocfl_band_c1.json` | 流利級 | Band C · Level 5 | 7 |
| `tocfl_band_c2.json` | 精通級 | Band C · Level 6 | 8 |

TOCFL berbasis **繁體** — jadi `t` adalah bentuk utama, `s` = konversi
繁→简. `zy` (注音) wajib. Set `"tocfl"` = angka di kolom terakhir.
Ikuti daftar resmi 國家華語測驗 (TOCFL 8000 詞 / 華語八千詞).
`tocfl_band_a1.json` sudah berisi benih — lengkapi.

---

## 4. Setelah mengisi

- Pastikan tiap file JSON valid. App otomatis memuat semua file (sudah
  terdaftar di `manifest.json`) — tidak perlu ubah kode.
- Tidak perlu menambah/menghapus file. Kalau menambah level baru, daftarkan
  juga di `manifest.json` (id, name, meta, standard, levelTag, asset).

---

## Paket Idiom (idioms.json)

`idioms.json` adalah bank idiom & peribahasa Mandarin. **Jangan diedit
tangan** — file ini di-generate oleh `build_idioms.py`. Untuk mengubah isi,
edit skripnya lalu jalankan ulang:

```
cd app/assets/packs
python build_idioms.py    # menulis idioms.json, mencetak TOTAL bank + per-kategori
```

Cara kerja `build_idioms.py`:

1. **Ekstrak** chengyu (成语) 4-karakter dari dataset HSK/TOCFL via `extract()`
   — menyaring `EXCLUDE` (compound noun / frasa fungsional) dan nama bahasa
   (`…语`/`…文`). Makna `m` Bahasa Indonesia ikut dari dataset.
2. **Augment** dari peta kanonik `AUG` (dikarang manual, hanya idiom/peribahasa
   yang mapan & nyata). Entri yang `s`-nya sudah ada di hasil ekstraksi
   di-skip otomatis.
3. Untuk tiap kartu: `zy` (注音) diturunkan **per-karakter dari hanzi**
   (`generate_hsk.get_word_zhuyin`, akurat), `tone` = nada suku kata pertama.
4. Kartu diurutkan menurut `py`, ditulis satu-kartu-per-baris.

Field tambahan khusus paket ini (di luar field standar `s/t/py/zy/m/tone`):

| field    | arti |
|----------|------|
| `lit`    | makna **harfiah** (terjemahan kata-per-kata, Bahasa Indonesia) |
| `cat`    | kategori: `chengyu` (成语 4-karakter) \| `yanyu` (谚语 peribahasa) \| `suyu` (俗语 ucapan sehari-hari) |
| `origin` | asal-usul/sumber idiom (opsional, boleh kosong) |

`m` = makna kiasan (Bahasa Indonesia natural), `lit` = harfiah. Tambahkan
idiom baru hanya bila yakin nyata & maknanya benar; jika ragu, **omit**.
Validasi: `flutter test test/idioms_pack_test.dart` (min. 820 kartu, semua
field wajib terisi, `cat` valid, non-idiom seperti 公共汽车/高速公路 absen).

# ZHONGWEN SHU (中文书) — Product Requirements Document (PRD)

| | |
|---|---|
| **Versi** | 1.0 |
| **Tanggal** | 2026-06-11 |
| **Status** | Design disetujui (brainstorm) → siap masuk fase Desain UI |
| **Lokasi project** | `D:\CLAUDE\ZHONG-WEN-SHU-2\` |
| **Build agent** | Claude Code (Opus 4.8) |
| **Dokumen terkait** | `ROADMAP.md`, `next-steps.md`, `SETUP.md` |

---

## 1. Ringkasan

**ZHONGWEN SHU** adalah aplikasi belajar bahasa Mandarin lintas-platform (Windows, Android, iOS menyusul) yang menggabungkan:

- **Flashcard ber-SRS** (spaced repetition) dengan beberapa mode tes,
- **Guru AI adaptif** — private chat (ala bimbingan) + sesi grup belajar bareng,
- **Latihan suara**: skoring pelafalan, deteksi nada, dan *tuner nada* real-time,
- **Games** untuk mengasah materi,
- **Sistem nilai ala sekolah** (rapor berbobot) + **leaderboard global**.

Aplikasi mendukung **DUA standar sekaligus**:
- **HSK** — China daratan, **简体 (simplified)**, romanisasi **拼音 (pinyin)**.
- **TOCFL** — Taiwan, **繁體 (traditional)**, romanisasi **注音 (zhuyin/bopomofo)**.

**Visi:** user jadi mahir berkomunikasi dalam Mandarin karena diajar AI yang menyesuaikan metode ke tiap murid, ditopang hafalan kosakata yang kuat (SRS) dan latihan bicara yang terukur.

---

## 2. Tujuan & Kriteria Sukses

**Tujuan utama:** aplikasi bisa *mengajar* Mandarin, bukan sekadar tempat hafalan. AI menyesuaikan metode ke kemampuan tiap murid.

**Kriteria sukses (bisa diuji):**
1. User bisa daftar (username unik + ID numerik unik), login, atur jalur belajar (简/繁/dua-duanya).
2. User bisa bikin/import/download deck, review kartu lewat SRS, dan ikut 3 mode tes.
3. User bisa chat dengan guru AI dan dapat materi harian yang nyambung dengan levelnya.
4. User bisa bikin/gabung room grup pakai invite code dan ikut sesi materi terjadwal.
5. User bisa latihan pelafalan dan dapat skor + lihat nada via tuner real-time.
6. Nilai dari semua aktivitas terhitung jadi rapor → menentukan posisi leaderboard.
7. Semua jalan di **free tier** untuk skala puluhan user.

---

## 3. Target User & Skala

- **Fase 1 (sekarang):** dipakai pemilik + dibagikan ke teman untuk *testing*. Skala **puluhan** user.
- **Fase 2:** setelah stabil → **publish** ke publik.
- **Implikasi:** arsitektur dirancang biar gampang di-scale, tapi semua komponen jalan di free tier dulu. Tidak ada monetisasi di fase ini.

---

## 4. Prinsip Produk

1. **Dwi-standar adalah warga kelas satu.** Setiap data kata menyimpan 简 + 繁 + 拼音 + 注音. Bukan tempelan.
2. **AI yang adaptif, digerakkan oleh rapor.** Guru membaca nilai & statistik SRS murid untuk menentukan materi.
3. **Offline-first untuk belajar.** Flashcard/SRS jalan tanpa internet (DB lokal). Fitur sosial & AI butuh online.
4. **Hemat & aman.** Semua API key di server (Edge Function), tidak pernah di client. Maksimalkan free tier + caching.
5. **Desain unik tapi tidak norak.** Identitas visual khas, modern, bukan nuansa "AI"/cyberpunk. Tanpa emoji di UI. Ikon lineart/solid yang simpel.

---

## 5. Tech Stack

| Lapisan | Pilihan | Catatan |
|---|---|---|
| Framework app | **Flutter** | Windows + Android (+ iOS nanti), satu codebase |
| State management | **Riverpod** (rekomendasi) | difinalkan di M0 |
| DB lokal | **Drift (SQLite)** | kartu, progress SRS, cache, offline |
| Backend | **Supabase** | Auth, Postgres, Realtime, Storage, Edge Functions |
| Auth email | **Supabase Auth + Resend (SMTP custom)** | email konfirmasi dari app, bukan Supabase |
| LLM (guru/chat) | **DeepSeek (free flash tier) via OpenCode Zen** gateway | OpenAI-compatible; diakses lewat Edge Function proxy. Model id final diverifikasi saat integrasi M2 |
| Pelafalan (scoring) | **Azure Speech – Pronunciation Assessment** | free tier; lewat proxy |
| Suara kartu (TTS) | **Edge-TTS** (gratis) + cache | suara daratan (zh-CN) & Taiwan (zh-TW); fallback `flutter_tts` |
| Deteksi nada/tuner | **On-device pitch detection** (YIN/autokorelasi) | gratis, offline |
| Algoritma SRS | **FSRS** | lebih akurat dari SM-2 (Anki) |
| Font Hanzi | **Kaiti (楷体)** | mendukung 简 & 繁 |

---

## 6. Lingkup Fitur (semuanya in-scope)

### 6.1 Auth & Identitas
- Login/Register (email + password), email konfirmasi via Resend.
- **Username** unik (bebas) + **ID numerik** unik (angka saja). Keduanya tidak boleh sama antar user.
- Profil: avatar, jalur belajar (简/繁/both), bio singkat, statistik.

### 6.2 Flashcard & SRS
- Kartu dwi-standar: front/back bebas, plus field 简/繁/拼音/注音/arti/contoh, **gambar**, **audio** (TTS otomatis + rekaman manual).
- **FSRS** menentukan jadwal review; melacak tingkat penguasaan tiap kartu.
- **Deck/grup kartu** (mis. kata kerja, sayuran, nama tempat).
- **3 mode tes** (semuanya mengukur penguasaan):
  1. **Multiple choice**
  2. **Self-check** (balik kartu sendiri, nilai sendiri benar/salah)
  3. **Spelling test** (ketik hanzi/pinyin)
- Tes bisa dipilih **per beberapa deck** atau **acak**.
- **Tulis kartu sendiri** & **import CSV**.
- **Download paket materi** (deck siap pakai HSK/TOCFL) lewat toggle — app default kosong.

### 6.3 Chat Guru Private (LLM)
- Chat AI seperti pada umumnya, tapi persona **guru bahasa**.
- Guru **kirim materi tiap hari** ke chat privat (ala bimbingan/konseling belajar).
- Materi **berkesinambungan** mengikuti level (HSK 1-6 / TOCFL) dan jalur murid.
- Guru menyesuaikan gaya & materi berdasarkan **rapor** murid (lihat §11).

### 6.4 Grup Belajar Bareng (Room)
- Konsep: les dalam satu ruangan. Host/admin bikin room → dapat **invite code / ID**.
- Anggota gabung pakai code (mirip grup WhatsApp).
- **Chat realtime** dalam room.
- Guru AI menaruh **materi terjadwal** (jam tertentu) yang berkesinambungan sesuai level room.
- Guru bisa **review kemampuan murid** di room.
- Peran: **host/admin** vs **murid**.

### 6.5 Voice & Tone
- **Pelafalan + skoring** (Azure): user ngomong → skor akurasi per suku kata + nada.
- **Deteksi nada 1-4** otomatis.
- **Tuner nada (ala tuner gitar)**: real-time, garis pitch user dibandingkan bentuk nada target (nada 1 datar, 2 naik, 3 turun-naik, 4 turun). On-device, gratis.

### 6.6 Tes Ngobrol
- Percakapan dengan guru AI (ketik/suara), dinilai (kelancaran, kosakata, ketepatan).

### 6.7 Games
- Set game (lihat §12), menarik dari kartu yang sudah dipelajari, menyumbang ke nilai "Praktek".

### 6.8 Sistem Nilai (Rapor)
- Komponen berbobot ala sekolah → nilai total + XP (lihat §11).

### 6.9 Leaderboard
- Global, format tier list **`[USERNAME] - [ID]`**, diranking dari nilai komposit rapor.

### 6.10 Settings
- Tema: **Dark / Light / By System**.
- **Toggle Zhuyin (注音) on/off**.
- Pilih jalur belajar (简/繁/both), sumber audio, bahasa antarmuka (ID/EN), notifikasi.

---

## 7. Model Data (dwi-standar)

Tabel inti (disederhanakan; final di M0):

**`vocab_entries`** (kamus master, dipakai bersama)
- `id`, `simplified`, `traditional`, `pinyin`, `zhuyin`, `meaning`, `example_zh`, `example_meaning`
- `audio_cn_url`, `audio_tw_url`, `image_url`
- `hsk_level` (1-6 / null), `tocfl_level` (1-7 / null), `tags[]`

**`cards`** (kartu milik user / di deck) — front/back custom + relasi ke `vocab_entries` (opsional)
**`decks`**, `deck_cards`
**`srs_state`** (FSRS): `card_id`, `user_id`, `stability`, `difficulty`, `due`, `reps`, `lapses`, `last_review`, `state`
**`profiles`**: `user_id`, `username` (unique), `numeric_id` (unique), `track` (`simplified`|`traditional`|`both`), `settings` (jsonb)
**`rooms`**: `id`, `invite_code`, `host_id`, `level`, `track`, `schedule`
**`room_members`**: `room_id`, `user_id`, `role` (`host`|`admin`|`student`)
**`messages`**: room & private chat (realtime)
**`materials`**: kurikulum/materi harian (di-cache, lihat §9)
**`grades`**: `user_id`, `component`, `score`, `weight`, `ref`, `created_at`
**`attendance`**: streak + kehadiran sesi grup
**`leaderboard`**: view turunan dari `grades`

> RLS (Row Level Security) aktif di semua tabel; user hanya akses datanya sendiri / room yang diikuti.

---

## 8. Arsitektur & Alur

```
┌─ Flutter App (Windows / Android / iOS-nanti) ───────────────┐
│  Navigasi tab bawah (Profil paling kanan)                   │
│  Lokal: Drift/SQLite (kartu, SRS, cache, offline)           │
└───────────────┬─────────────────────────────────────────────┘
                │ HTTPS / Realtime
┌───────────────▼── Supabase ─────────────────────────────────┐
│  Auth (+ Resend SMTP) · Postgres (+ RLS) · Realtime          │
│  Storage (audio/gambar, paket materi)                        │
│  Edge Functions:                                             │
│    • llm-proxy        (panggil DeepSeek via OpenCode Zen)    │
│    • scoring-proxy    (Azure pronunciation)                  │
│    • curriculum-gen   (generate & cache materi)             │
│    • rate-limiter     (kuota per user)                       │
└───────┬───────────────────────────┬─────────────────────────┘
        │                           │
  OpenCode Zen → DeepSeek      Azure Speech     Edge-TTS (suara, di-cache)
```

**Prinsip alur:** belajar (SRS/flashcard) = lokal/offline; sosial + AI + scoring = lewat Supabase; **tidak ada API key di client**.

---

## 9. Strategi LLM (hemat & aman)

Model gratis = ada **rate limit**. Strategi:

1. **Proxy 1 key** lewat Edge Function `llm-proxy`. (Fase 2 saat publish: upgrade/rotasi key.)
2. **Materi & kurikulum di-cache.** `curriculum-gen` membuat materi per (level × jalur) **sekali**, simpan di tabel `materials`. Semua user baca dari cache — **bukan** panggil LLM per user.
3. **LLM live hanya untuk:** private chat, tes ngobrol, tanya-jawab bebas, feedback personal.
4. **Rate-limit + kuota per user** di server. Saat limit kena → degradasi anggun (sajikan cache / antre).
5. **Desain prompt:** persona guru, sadar dwi-standar (ikut jalur murid), memakai **rapor + statistik SRS** murid untuk adaptasi.

---

## 10. Strategi Voice & Audio

| Fitur | Cara | Biaya |
|---|---|---|
| Tuner nada & latihan nada | On-device pitch detection (YIN/autokorelasi), visual kontur vs target | Gratis, offline |
| Skoring pelafalan | Azure Pronunciation Assessment via `scoring-proxy` (key di server) | Free tier (cap ~5 jam/bln) → cache hasil, batasi percobaan |
| Suara kartu (TTS) | Edge-TTS generate-on-demand → **cache** (device + Storage); voice zh-CN & zh-TW | Gratis |
| Fallback TTS | `flutter_tts` (suara OS) saat offline | Gratis |

---

## 11. Sistem Nilai (Rapor) & Leaderboard

Komponen berbobot (bobot **default**, bisa diatur):

| Komponen | Sumber | Bobot |
|---|---|---|
| **Kehadiran** | Streak harian + ikut sesi grup | 10% |
| **PR** | Mengerjakan materi harian guru | 20% |
| **Ujian Harian** | Quiz / games | 20% |
| **Praktek** | Review SRS + latihan pelafalan/nada | 25% |
| **Ujian Akhir** | Level test (HSK/TOCFL) | 25% |

- Total → **Nilai (0-100) + XP** → menentukan **tier leaderboard global** (`[USERNAME] - [ID]`).
- **Guru AI membaca rapor** untuk menyesuaikan materi tiap murid.

---

## 12. Games (usulan set awal)

1. **Match** — pasangkan 汉字 ↔ pinyin/arti.
2. **Tebak Nada** — dengar/lihat kata, pilih nada (4 opsi).
3. **Listening Quiz** — dengar audio → pilih jawaban.
4. **Susun Kalimat** — sentence scramble.
5. **Speed Recall** — kebut kartu dalam waktu terbatas.

Semua narik dari kartu yang **sudah dipelajari** dan menyumbang ke nilai **Praktek**.

---

## 13. Prinsip Desain UI/UX

- **Identitas khas & ownable**, modern; **bukan** nuansa "AI"/cyberpunk; **tidak norak**.
- **TANPA emoji** di UI.
- **Ikon**: satu keluarga ikon **lineart atau solid** yang simpel & konsisten.
- **Font Hanzi**: **Kaiti**. Font Latin UI: sans modern bersih (dipilih di fase Desain).
- **Tema**: Dark / Light / By System (toggle).
- **Tampilan dwi-standar**: tampilkan 简/繁 sesuai jalur; pinyin/zhuyin sesuai setting (zhuyin bisa dimatikan).
- **Navigasi (usulan, 5 tab bawah, Profil paling kanan):**
  1. **Beranda** (dashboard, rapor ringkas, materi hari ini, akses leaderboard)
  2. **Belajar** (flashcard/SRS, deck, tes, import, paket materi, games)
  3. **Grup** (room belajar bareng)
  4. **Guru** (chat private + tes ngobrol + latihan voice)
  5. **Profil** (akun, settings, pencapaian)
  > Catatan: brief minta "tiap fitur punya tab" — 7+ tab bawah jelek secara UX. 5 tab di atas adalah usulan; **final ditentukan di fase Desain UI**.
- Warna, logo, ikon: ditentukan agent di **fase Desain UI** (mockup HTML dulu).

---

## 14. Kebutuhan Non-Fungsional

- **Platform:** Windows (installer MSIX/EXE), Android (APK install manual), iOS (ditunda — butuh Mac + Apple Developer $99/thn).
- **Offline:** flashcard/SRS jalan offline; fitur sosial/AI butuh online.
- **Keamanan:** tidak ada secret di client; RLS di semua tabel; semua panggilan LLM/scoring lewat Edge Function.
- **Biaya:** semua di free tier (Supabase, OpenCode Zen/DeepSeek, Azure, Resend). Pantau limit.
- **Privasi:** `acc.env`/kredensial server-side only; jangan pernah dikirim ke LLM.

---

## 15. Integrasi & Kredensial yang Dibutuhkan

| Layanan | Dipakai untuk | Sisi |
|---|---|---|
| **Supabase** (URL + anon key; service key) | Auth/DB/Realtime/Storage/Functions | client (anon) + server (service) |
| **OpenCode Zen** API key | Akses DeepSeek (guru/chat) | server (Edge Function) |
| **Azure Speech** key + region | Skoring pelafalan | server (Edge Function) |
| **Resend** API key (+ domain opsional) | Email konfirmasi | server (Supabase SMTP) |
| **Kaiti font** | Render hanzi | bundle di app |

> Status akun: Azure ✅ (sudah dibuat). Sisanya disiapkan saat M0/M2 (lihat `SETUP.md`).

---

## 16. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Rate limit LLM gratis | Cache materi/kurikulum, rate-limiter per user, degradasi anggun |
| Cap Azure free tier (~5 jam/bln) | Cache hasil, batasi percobaan, tuner on-device sebagai andalan gratis |
| Akurasi ASR Mandarin | Set ekspektasi; tuner nada selalu tersedia (gratis) |
| Build iOS butuh Mac | Ditunda ke fase berikutnya |
| 1 key LLM dipakai bareng → abuse | Auth wajib + rate limit |
| Email Supabase masuk spam/limit kecil | Resend SMTP custom |

---

## 17. Di Luar Lingkup (sekarang)

- Rilis iOS & App/Play Store.
- Monetisasi/pembayaran.
- Versi web (mungkin nanti via Flutter Web).
- Bahasa antarmuka selain ID/EN.

---

## 18. Milestone

Detail di **`ROADMAP.md`**. Ringkas: **Fase Desain UI** → M0 Fondasi → M1 Flashcard/SRS → M2 Chat Guru → M3 Grup → M4 Voice → M5 Games+Rapor+Leaderboard → M6 Tes Ngobrol + Packaging. Semua fitur tetap dibangun; ini urutan dependency.

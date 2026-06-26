# ZHONGWEN SHU — ROADMAP

Semua fitur **tetap dibangun**. Ini urutan berdasarkan dependency biar tidak chaos. Tiap milestone harus jalan & teruji sebelum lanjut.

> Aturan main: tiap milestone = spec ringkas (writing-plans) → implement (TDD) → verifikasi → lanjut.

---

## Fase Desain UI (sebelum coding)
**Tujuan:** kunci identitas visual sebelum nulis kode.
- **Mockup dibuat user lewat "claude design"** — builder (Claude Code) TIDAK bikin mockup sendiri, cuma mengikuti konsepnya.
- Cakup layar inti: Beranda, Belajar/flashcard, review SRS, Chat Guru, Grup, Voice/tuner, Leaderboard, Profil/Settings.
- Aturan baku tetap wajib: Kaiti hanzi, tanpa emoji, ikon lineart/solid, unik tapi tidak norak (acuan: skill `zws-design-system` + PRD §13).
- Simpan hasil/aset mockup ke `docs/ui/` sebagai acuan builder.

---

## M0 — Fondasi
- Scaffold Flutter (Windows + Android), struktur folder, Riverpod, theming (dark/light/system).
- Integrasi Supabase (project, env, client).
- **Auth**: register/login, **username unik + ID numerik unik**, Resend SMTP.
- **Model data dwi-standar** (Postgres + RLS) + **Drift** lokal + skema sinkronisasi.
- Navigasi tab bawah (sesuai fase Desain).
- **Definition of done:** bisa daftar→login→lihat profil di Windows & Android; tema jalan; data tersimpan lokal+cloud.

## M1 — Flashcard & SRS  *(prioritas)*
- Engine **FSRS**; kartu dwi-standar (front/back + 简/繁/拼音/注音/arti/gambar/audio).
- Deck/grup kartu; tulis kartu sendiri; **import CSV**.
- **3 mode tes** (multiple choice, self-check, spelling) — pilih per deck / acak.
- **TTS Edge-TTS** + cache; **download paket materi** (HSK/TOCFL).
- **Definition of done:** review SRS jalan offline; 3 mode tes terukur; import & paket materi berfungsi.

## M2 — Chat Guru Private (LLM)  *(prioritas)*
- Edge Function `llm-proxy` (DeepSeek via OpenCode Zen) + `rate-limiter`.
- Private chat persona guru; **materi harian**; adaptasi dari rapor/SRS.
- `curriculum-gen` + cache materi.
- **Definition of done:** chat jalan via proxy (tanpa key di client); materi harian muncul & nyambung level; rate limit aktif.

## M3 — Grup Belajar Bareng  *(prioritas)*
- Room + **invite code/ID**; peran host/admin/murid.
- **Chat realtime** (Supabase Realtime).
- Materi terjadwal di room; guru review murid.
- **Definition of done:** bikin/gabung room via code; chat realtime; materi terjadwal tampil.

## M4 — Voice & Tone
- **Tuner nada** real-time (on-device pitch).
- Latihan nada 1-4 + **skoring pelafalan** (Azure via `scoring-proxy`).
- **Definition of done:** tuner akurat menampilkan kontur; skoring memberi nilai per suku kata; hasil masuk nilai Praktek.

## M5 — Games + Rapor + Leaderboard
- 5 game (§12 PRD); **sistem nilai berbobot** (rapor); **leaderboard global**.
- **Definition of done:** game menyumbang nilai; rapor terhitung; leaderboard tampil `[USERNAME] - [ID]`.

## M6 — Tes Ngobrol + Polish + Packaging
- Tes ngobrol (percakapan dinilai).
- Polish UI, empty states, error handling, i18n (ID/EN).
- **Packaging**: Windows installer (MSIX/EXE), Android APK.
- **Definition of done:** installer Windows & APK terbangun; alur end-to-end mulus.

---

## Catatan urutan
- **M1-M3 = prioritas** lu (flashcard, chat guru, grup) → didahulukan setelah fondasi.
- iOS **tidak** di roadmap ini (butuh Mac + Apple Developer). Ditambahkan saat siap publish.

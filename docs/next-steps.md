# ZHONGWEN SHU — Next Steps

Urutan langkah setelah sesi PRD ini. **Belum ada build apps** sampai fase Desain UI selesai & lu setujui.

## 0. Sekarang — review
- [ ] Baca `docs/PRD.md` & `docs/ROADMAP.md`. Kasih revisi kalau ada.
- [ ] (Opsional) jalanin install berat di `docs/SETUP.md` bagian B — atau minta gw jalanin.

## 1. Akun & key (paralel, bisa sambil jalan)
- [ ] Bikin project **Supabase** → simpan URL + anon key + service key.
- [ ] Ambil **OpenCode Zen** API key.
- [ ] Ambil **Azure Speech** key + region (akun sudah ada).
- [ ] Daftar **Resend** → API key.
> Simpan di file `acc.env` (JANGAN di-commit, JANGAN dikirim ke LLM).
> 📘 Tutorial langkah demi langkah: `docs/accounts-setup.md` · Template: `acc.env.example`.

## 2. Fase Desain UI — via "claude design" (oleh user)
- **User bikin mockup pakai "claude design"**; builder (Claude Code) ikutin konsepnya. Builder TIDAK bikin mockup sendiri.
- Cakup layar inti; taruh hasil/aset ke `docs/ui/` sebagai acuan builder.
- Aturan baku: skill `zws-design-system` + `docs/PRD.md` §13.

## 3. Build per milestone (pakai superpowers)
Untuk tiap milestone (M0 → M6) di `ROADMAP.md`:
1. `writing-plans` → rencana implementasi detail milestone itu.
2. `test-driven-development` → implement.
3. `verification-before-completion` → buktikan jalan.
4. Lanjut milestone berikutnya.

Urutan: **M0 Fondasi → M1 Flashcard/SRS → M2 Chat Guru → M3 Grup → M4 Voice → M5 Games+Rapor+Leaderboard → M6 Tes Ngobrol + Packaging.**

## 4. Tips menjalankan
- Jalankan Claude Code **dari** `D:\CLAUDE\ZHONG-WEN-SHU-2\` supaya `CLAUDE.md` + skill ke-load otomatis.
- Sebelum kerja di subsistem, skill terkait (`zws-*`) jadi acuan.

---

### Daftar file hasil sesi ini
- `CLAUDE.md` — konteks project (auto-load)
- `docs/PRD.md` — spec lengkap
- `docs/ROADMAP.md` — milestone
- `docs/SETUP.md` — tools & akun
- `docs/next-steps.md` — file ini
- `.claude/skills/zws-design-system|zws-supabase-backend|zws-llm-teacher|zws-flashcard-srs|zws-voice-tone`

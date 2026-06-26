# ZHONGWEN SHU — SETUP (Tools & Akun)

Status deteksi mesin (2026-06-11):

| Tool | Status | Catatan |
|---|---|---|
| Git | ✅ ada | — |
| Node + npm | ✅ ada | dipakai untuk tooling + Supabase CLI (npx) |
| JDK 17 | ✅ ada | untuk build Android |
| VS Code | ✅ ada | editor |
| Python | ✅ ada | util |
| winget | ✅ ada | installer |
| **Deno** | ✅ **baru diinstall** | runtime Edge Functions (lokal) |
| **Flutter / Dart** | ❌ belum | **WAJIB** — backbone app |
| **Supabase CLI** | ❌ belum | dipasang sebagai dev-dependency di M0 (`npx supabase`) |
| **Android SDK / adb** | ❌ belum | untuk build/install APK |
| **Visual Studio C++** | ❌ belum (perlu dicek) | **WAJIB** untuk build Windows desktop |
| **Kaiti font** | ❌ belum | di-bundle ke app (M1) |

---

## A. Yang sudah gw urus
- ✅ Deno terpasang via winget.
- ✅ Struktur folder project + dokumen + skill dibuat.

## B. Install berat — command siap pakai (jalankan saat mulai build / M0)

> Ini download besar (GB-an) & butuh setup PATH, makanya gw taruh sebagai command, bukan auto-run diam-diam. Bilang aja kalau mau gw jalanin sekarang.

**1. Flutter SDK (termasuk Dart)** — clone stable lalu tambah PATH:
```powershell
git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
setx PATH "$($env:PATH);C:\src\flutter\bin"
# buka PowerShell baru, lalu:
flutter doctor
```

**2. Visual Studio 2022 + workload C++ (untuk build Windows):**
```powershell
winget install --id Microsoft.VisualStudio.2022.Community -e `
  --override "--add Microsoft.VisualStudio.Workload.NativeDesktop --includeRecommended --quiet --norestart"
```

**3. Android Studio (SDK + emulator + adb):**
```powershell
winget install --id Google.AndroidStudio -e
# lalu buka sekali untuk install SDK, kemudian:
flutter doctor --android-licenses
```

**4. Supabase CLI** — dipasang per-project saat M0 (tanpa global):
```powershell
# dijalankan di folder project saat M0:
npm i supabase --save-dev
npx supabase --version
```

Setelah semua → `flutter doctor` harus hijau untuk Windows + Android.

## C. Akun & API key (lu yang bikin; gw gak bisa bikinin)

| Layanan | Untuk | Status |
|---|---|---|
| **Supabase** | backend (DB/Auth/Realtime/Storage/Functions) | ⬜ bikin project |
| **OpenCode Zen** | API key akses DeepSeek (guru/chat) | ⬜ ambil key |
| **Azure Speech** | skoring pelafalan | ✅ akun dibuat → tinggal ambil key+region |
| **Resend** | email konfirmasi (SMTP custom) | ⬜ daftar, ambil key |

> Semua key (kecuali Supabase **anon** key) HANYA dipakai di Edge Function (`supabase secrets set`). Jangan pernah ditaruh di kode client. Jangan kirim ke LLM.

## D. Font Kaiti
- Perlu file Kaiti TTF yang mencakup **简 + 繁**. Rencana: bundle **TW-Kai** (gratis, cakupan 繁 luas) + kai simplified. Gw bisa carikan & siapkan file-nya saat M1.

---

## Cara mengaktifkan skill project ini
Project skills ada di `.claude/skills/`. Biar ke-load: **jalankan Claude Code dari folder project** `D:\CLAUDE\ZHONG-WEN-SHU-2\` (CLAUDE.md & skill otomatis terbaca). Alternatif: salin folder `.claude/skills/*` ke `C:\Users\hendr\.claude\skills\` biar global.

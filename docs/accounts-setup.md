# Tutorial Setup Akun & API Key — ZHONGWEN SHU

> Disiapkan untuk dipakai pas **building phase**. Aturan emas: **semua key kecuali Supabase anon = SERVER ONLY** (cuma di Edge Function via `supabase secrets set`). Jangan taruh di client. Jangan kirim ke LLM. Isi nilainya ke `acc.env` (lihat `acc.env.example`).

---

## 1. SUPABASE — backend (Auth, DB, Realtime, Storage, Edge Functions)

**Yang kita butuh:** `Project URL`, `anon key` (client), `service_role key` (server). Nanti + SMTP (Resend) untuk email.

### Langkah
1. Buka **https://supabase.com** → **Start your project** → sign in (GitHub/email).
2. Bikin **Organization** (kalau belum) → **New project**.
3. Isi:
   - **Name:** `zhongwen-shu`
   - **Database Password:** bikin yang kuat → **SIMPAN** (buat akses DB langsung).
   - **Region:** **Southeast Asia (Singapore)** — paling dekat Indonesia.
   - **Plan:** Free.
4. Tunggu provisioning (~2 menit).
5. Ambil kredensial: ikon **Settings (gear)** → **API**:
   - **Project URL** → isi ke `SUPABASE_URL`
   - **Project API keys → `anon` `public`** → `SUPABASE_ANON_KEY` *(boleh di client/Flutter)*
   - **Project API keys → `service_role` `secret`** → `SUPABASE_SERVICE_ROLE_KEY` *(SERVER ONLY, rahasia)*
6. *(Nanti saat M0)* **Authentication → Providers → Email** = aktif; **Email confirmation** = ON.
7. *(Nanti)* **Custom SMTP** pakai Resend → lihat bagian 4.

### Catatan free tier (cukup buat puluhan user)
- Project **auto-pause** kalau idle ~1 minggu — tinggal di-resume dari dashboard. Wajar buat fase tes.
- DB ~500MB + Storage beberapa GB → cukup untuk testing.

### Masuk ke `acc.env`
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`. (DB password simpan terpisah, gak dipakai app.)

---

## 2. AZURE SPEECH — skoring pelafalan (akun sudah ada)

**Yang kita butuh:** sebuah **Speech resource** → ambil **Key** + **Region**.

### Langkah
1. Buka **https://portal.azure.com** → login.
2. **Create a resource** → cari **"Speech"** → pilih **Speech Services** (by Microsoft) → **Create**.
3. Isi:
   - **Subscription:** punya lu
   - **Resource group:** Create new → `zhongwen-shu-rg`
   - **Region:** **Southeast Asia** (atau East Asia)
   - **Name:** `zhongwen-shu-speech`
   - **Pricing tier:** **Free F0** (gratis; 1 per region per subscription). Kalau F0 gak tersedia → **S0** (bayar sesuai pakai).
4. **Review + Create** → **Create**. Tunggu deploy → **Go to resource**.
5. Menu kiri **Keys and Endpoint**:
   - **KEY 1** → `AZURE_SPEECH_KEY`
   - **Location/Region** (mis. `southeastasia`) → `AZURE_SPEECH_REGION`

### Catatan free tier (F0)
- **Speech-to-Text + Pronunciation Assessment: 5 jam audio/bulan gratis.** Strategi kita: cache hasil + batasi percobaan per user/hari biar muat. Latihan harian pakai **tuner on-device** (gratis tanpa batas).

### Masuk ke `acc.env`
`AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION`.

---

## 3. OPENCODE ZEN — LLM guru (DeepSeek) *(sekalian, dipakai M2)*

**Yang kita butuh:** API key + base URL (OpenAI-compatible) + model id.

### Langkah
1. Buka situs **OpenCode Zen** (gateway dari tim OpenCode/SST) → sign in.
2. Bagian **API keys** → buat key baru → `OPENCODE_ZEN_API_KEY`.
3. Catat **base URL** endpoint (OpenAI-compatible) → `OPENCODE_ZEN_BASE_URL`.
4. Catat **model id** DeepSeek free flash → `OPENCODE_ZEN_MODEL`.
> Detail persis (nama model & endpoint) diverifikasi pas integrasi M2.

---

## 4. RESEND — email konfirmasi *(sekalian, dipakai M0)*

### Langkah
1. Buka **https://resend.com** → sign up.
2. **API Keys → Create** → `RESEND_API_KEY`.
3. *(Opsional tapi disarankan)* **Domains → Add Domain** → verifikasi DNS (biar email dari domain lu). Buat tes, boleh pakai domain bawaan `onboarding@resend.dev`.
4. **Sambungkan ke Supabase:** Supabase → **Authentication → SMTP Settings → Enable Custom SMTP**:
   - **Host:** `smtp.resend.com`
   - **Port:** `465` (SSL) atau `587`
   - **Username:** `resend`
   - **Password:** `RESEND_API_KEY`
   - **Sender email:** `no-reply@domainlu` (atau `onboarding@resend.dev` buat tes)
   - **Sender name:** `ZHONGWEN SHU`

---

## Ringkasan: apa masuk ke mana

| Key | Dipakai di | Rahasia? |
|---|---|---|
| `SUPABASE_URL` | client + server | tidak |
| `SUPABASE_ANON_KEY` | client (Flutter) | tidak (publik) |
| `SUPABASE_SERVICE_ROLE_KEY` | server (Edge Fn) | **YA** |
| `AZURE_SPEECH_KEY` / `_REGION` | server (Edge Fn) | **YA** |
| `OPENCODE_ZEN_*` | server (Edge Fn) | **YA** |
| `RESEND_API_KEY` | Supabase SMTP (server) | **YA** |

Isi semua ke `acc.env` (template: `acc.env.example`). File `acc.env` sudah di-`.gitignore`.

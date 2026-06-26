# ZHONGWEN SHU (中文书) — Backend Handoff for Claude Code

> **Status:** UI prototype is locked (`Zhongwen Shu.dc.html` + `ZWSApp.dc.html`). This document hands the **backend** off to Claude Code. The prototype is the source of truth for *what the app does*; this doc describes *what the backend must provide* so the real Flutter app can replace the prototype's in-memory mock data with live APIs.

---

## 0. Context & constraints

| | |
|---|---|
| **Product** | Mandarin learning app, dual-standard: **HSK** (Mainland · 简体 · 拼音 pinyin) **and** **TOCFL** (Taiwan · 繁體 · 注音 zhuyin). |
| **Client** | Flutter — targets **Windows desktop** + **Android**. The prototype mocks both form factors. |
| **UI language** | Indonesian (with Mandarin terms). Keep API enums in English; user-facing copy stays in the client. |
| **Tracks** | A user picks a learning track: `simplified` / `traditional` / `both`. Every vocab item stores **all four** representations (简, 繁, 拼音, 注音) so a track switch is a display toggle, never a data migration. |
| **Auth** | Per-user accounts (the prototype shows user "Andi", id `#2207`). Assume email/password or device account; tokens for the mobile/desktop client. |

> ⚠️ **Do not** treat any names, scores, or sample sentences in the prototype as real data — they are seed/mock values for layout only.

---

## 1. Data model

Tables (relational; Postgres assumed — adjust to your chosen stack). Names are suggestions.

### `users`
| field | type | notes |
|---|---|---|
| `id` | uuid (pk) | |
| `display_name` | text | "Andi" |
| `handle` | text unique | "andi" |
| `public_id` | text | short id shown in UI ("#2207") |
| `track` | enum(`simplified`,`traditional`,`both`) | learning path, chosen at onboarding, editable in Profile |
| `show_zhuyin` | bool | settings toggle (注音 on cards) |
| `theme` | enum(`light`,`dark`) | optional server-persisted; client may keep locally |
| `ui_lang` | enum(`id`,`en`) | |
| `xp` | int | running total, drives leaderboard |
| `created_at` | timestamptz | |

### `decks`
| field | type | notes |
|---|---|---|
| `id` | uuid (pk) | |
| `owner_id` | uuid → users | null = system/seed deck |
| `name` | text | "Sapaan & Sopan Santun" |
| `position` | int | display order ("№ 01") |
| `is_pack` | bool | true for ready-made packs (HSK 1, HSK 2, TOCFL Band A) |
| `standard` | enum(`hsk`,`tocfl`,`mixed`) | |
| `level_tag` | text | "HSK 2", "TOCFL Band A" |

### `cards`
| field | type | notes |
|---|---|---|
| `id` | uuid (pk) | |
| `deck_id` | uuid → decks | |
| `simplified` | text | 简体 — e.g. 喜欢 |
| `traditional` | text | 繁體 — e.g. 喜歡 |
| `pinyin` | text | "xǐhuan" (tone marks) |
| `zhuyin` | text | "ㄒㄧˇ ㄏㄨㄢ˙" |
| `meaning_id` | text | Indonesian gloss — "suka" |
| `example_s` | text | simplified example sentence |
| `example_t` | text | traditional example sentence |
| `example_id` | text | Indonesian translation of example |
| `tone` | smallint | 1–4 (5 = neutral) for the headword; used by Tebak Nada |
| `created_by` | uuid → users | for user-authored cards (see §3 Write) |

> The prototype's `VOCAB` array in `ZWSApp.dc.html` is the field-for-field shape of a `card`. Mirror it.

### `card_states` (SRS, one row per user×card)
| field | type | notes |
|---|---|---|
| `user_id` | uuid → users | |
| `card_id` | uuid → cards | |
| `stability` | float | FSRS |
| `difficulty` | float | FSRS |
| `due_at` | timestamptz | when it re-enters review |
| `last_reviewed_at` | timestamptz | |
| `reps` | int | |
| `lapses` | int | |
| `mastery` | smallint(0–3) | derived bucket for the deck list color code (see §2) |
| pk | (`user_id`,`card_id`) | |

### `study_sessions` & `session_events`
Log every Review / Test / Game run for the **rapor** (§4) and history.
- `study_sessions`: `id, user_id, kind(enum), deck_id?, total, correct, started_at, ended_at, score`
- `kind` ∈ `review_srs`, `test_mc`, `test_self`, `test_spell`, `game_tone`, `game_match`, `game_listen`, `game_speed`, `pronunciation`
- `session_events`: per-item `card_id, correct, latency_ms, rating?`

### `groups` / `group_members` / `group_messages`
- `groups`: `id, name (早班 "Kelas Pagi"), invite_code (ZWS-7F3K), level_tag, owner_id`
- `group_members`: `group_id, user_id, role(enum teacher|student), joined_at, online`
- `group_messages`: `id, group_id, user_id (null = Guru AI), body, created_at`
- `group_sessions`: scheduled study sessions — `group_id, topic (量词), scheduled_at, created_by_ai bool`

### `tutor_threads` / `tutor_messages` (Guru AI, private 1:1)
- `tutor_threads`: `id, user_id, curriculum_unit (e.g. "HSK 2 · Unit 4"), updated_at`
- `tutor_messages`: `id, thread_id, role(enum user|tutor), body, created_at`
- `daily_assignments`: `id, user_id, card_id?/topic, prompt ("buat 3 kalimat dgn 喜欢"), status(enum assigned|submitted|graded), grade?, feedback?` — this is the "Materi dari Guru · hari ini" card on Beranda and feeds the **PR** rapor component.

---

## 2. Mastery color code (deck card list)

The deck detail list color-codes each card by `mastery` bucket. Backend computes `mastery` from FSRS state; client just renders the color.

| bucket | label (ID) | color | rule of thumb |
|---|---|---|---|
| 0 | Baru | `#9a948a` gray | never reviewed (`reps = 0`) |
| 1 | Perlu latihan | `#b23b2e` seal red | low stability / recent lapse |
| 2 | Cukup | `#b8862f` gold | mid stability |
| 3 | Mahir | `#3a9e6a` green | high stability, due far out |

Pick concrete thresholds from FSRS `stability` (e.g. <1d, <7d, <30d, ≥30d) — tune later. Expose `mastery` (0–3) on the card-list endpoint.

---

## 3. Core flows → endpoints

All endpoints assume the authenticated user. Suggested REST shape (swap for GraphQL/RPC as you like).

### Onboarding / Profile
- `PATCH /me` — set `track`, `show_zhuyin`, `theme`, `ui_lang`.
- `GET /me` — profile + `xp` + rank.

### Decks & cards
- `GET /decks` — user's decks + packs, each with `card_count`, `mastered_pct`, `due_count`.
- `GET /decks/:id/cards` — card list **with per-user `mastery`** (drives the color code). Include user-authored cards.
- `POST /decks/:id/cards` — **Add/Write card.** Body: `{ simplified, traditional?, pinyin?, meaning_id?, ... }`. Used by both the in-deck "+ Tambah kartu" form and the standalone **Tulis kartu** screen (which also lets the user choose the target deck). Minimum required: a headword + meaning; backend can auto-fill `traditional`/`zhuyin` via a conversion service if missing.
- `GET /packs/:id` + `POST /packs/:id/install` — download a ready-made pack into the user's library ("Unduh" → "Terunduh").

### Review (SRS) — **Benar / Salah only**
The UI deliberately reduced rating to **two buttons**. Map them to FSRS grades:
- **Salah** → `Again`
- **Benar** → `Good`

(You may internally still support Hard/Easy, but the client only sends `again`/`good`.)

- `GET /review/queue?deck_id=&limit=` — due cards (FSRS order). `limit` comes from the question-count stepper (multiples of 10, max 200) where applicable; plain review uses due count.
- `POST /review/grade` — `{ card_id, grade: "again"|"good", latency_ms }` → returns updated `due_at`, `mastery`. Append to `session_events`.
- `POST /sessions` — open/close a `review_srs` session; on close, bump **Praktek** rapor + XP.

### Tests (Mode Tes — picker with 3 modes)
The client first shows a **mode picker** + a **question-count stepper** (10–200, ×10). Then:
- **Pilihan Ganda (MC):** `GET /tests/mc?deck_id=&count=` → N items, each `{ card_id, prompt_hanzi, options[4 meanings] }`. One correct = card meaning; 3 distractors = other cards' meanings. `POST /tests/mc/answer` (or batch on finish).
- **Self-check:** same flip card as review but logged as a test; client sends Benar/Salah per card.
- **Tes Ejaan (spelling):** `GET /tests/spell?deck_id=&count=` → `{ card_id, prompt_hanzi, audio_url }`; user types **pinyin**; backend (or client) normalizes (strip tone marks/diacritics, lowercase, ignore spaces) and compares to `pinyin`. Placeholder copy is just "Ketik di sini".

All test results write a `study_sessions` row of the matching `kind` and feed **Ujian Harian** (see §4).

### Games
Question count from the same stepper feeds the sequential games.
- **Tebak Nada** (`game_tone`): `GET /games/tone?count=` → `{ card_id, hanzi, audio_url, tone }`; **no pinyin shown**; client autoplays audio. User picks tone 1–4.
- **Match** (`game_match`): `GET /games/match?deck_id=` → 6 pairs `{ card_id, hanzi, meaning_id }`; client shuffles into 12 tiles. Pure client scoring; post final `{ moves, pairs }`.
- **Listening Quiz** (`game_listen`): like MC but the prompt is **audio only** (`audio_url`), options are meanings.
- **Speed Recall** (`game_speed`): `GET /games/speed?count=` → MC items; client runs a **45-second timer**, counts correct. Post `{ correct, duration_s }`.

### Voice & Tone (Guru → Suara & Nada)
- **Pronunciation scoring:** `POST /voice/score` — multipart audio + `card_id` → `{ overall, syllables: [{ text, score }] }`. Prototype shows per-syllable bars (e.g. 你 92, 好 74). Use a speech-assessment service (Azure Pronunciation Assessment or equivalent) server-side.
- **Tuner (pitch):** **runs on-device** in the real app (real-time mic → pitch contour vs target tone shape). The prototype implements this client-side with WebAudio autocorrelation; in Flutter use a native mic/pitch plugin. **No backend needed** beyond serving target contours (static per tone) and logging optional results.
- **TTS / audio_url:** every `audio_url` above = synthesized speech. Provide **both** `zh-CN` and `zh-TW` voices; pick by the card's standard / user track. Cache aggressively.

### Guru AI (private chat + daily curriculum)
- `GET /tutor/thread` — current thread + `curriculum_unit` + messages.
- `POST /tutor/message` — `{ body }` → streams/returns tutor reply. The tutor **continues a curriculum** day-to-day (the "Materi harian · berkesinambungan" banner). Back it with an LLM + per-user state: current unit, target words, recent errors.
- `GET /tutor/today` — today's assignment for the Beranda "Materi dari Guru" card.
- `POST /tutor/assignment/:id/submit` → tutor grades PR, writes `grade`+`feedback`, updates **PR** rapor.

### Groups (realtime)
- `GET /groups` / `POST /groups/join {invite_code}` / `POST /groups` (create).
- `GET /groups/:id/messages` + **WebSocket** channel `group:{id}` for realtime chat + presence (online count). Guru AI can post scheduled-session announcements (量词 @ 19:30).
- `group_sessions` scheduled by the AI/teacher.

### Leaderboard
- `GET /leaderboard?scope=global` → ranked users by `xp`/score with tier (S/A/B). Beranda shows top 3 + "Lihat semua".

---

## 4. Rapor (weighted report card)

Profile shows a weighted grade (prototype: **86 / A−**). Compute server-side from logged sessions:

| component | weight | source |
|---|---|---|
| Kehadiran (attendance) | 10% | daily app-open / streak |
| PR (materi guru) | 20% | `daily_assignments` grades |
| Ujian Harian | 20% | `test_*` session scores |
| Praktek | 25% | `review_srs` + `pronunciation` + games |
| Ujian Akhir | 25% | periodic exam (define later) |

`grade = Σ(component% × weight)`. Map to letter (A−, etc.). Expose `GET /me/rapor` → `{ total, letter, components: [{name, weight, score}] }`. The **streak** ("12 hari") and **XP** also surface on Beranda.

---

## 5. Prototype → backend mapping cheat-sheet

| Prototype (in-memory) | Replace with |
|---|---|
| `VOCAB[]` array | `cards` table + `GET /decks/:id/cards` |
| `DECKS[]` array | `decks` table + `GET /decks` |
| `customCards{}` / `saveCard()` / `saveWrite()` | `POST /decks/:id/cards` |
| `card.lv` (mastery 0–3) | server-computed `mastery` from FSRS |
| `rate(true/false)` | `POST /review/grade {grade: good/again}` |
| `buildQuiz()` distractors | `GET /tests/mc` (server picks distractors) |
| `speak()` (WebSpeech) | `audio_url` from server TTS (zh-CN/zh-TW) |
| Tuner WebAudio autocorrelation | native on-device pitch (Flutter plugin) |
| `messages[]` (Guru) | `GET/POST /tutor/*` (LLM-backed) |
| `roomMessages[]` (Grup) | WebSocket `group:{id}` |
| `leaderTop` / `leaderAll` | `GET /leaderboard` |
| `rapor[]` | `GET /me/rapor` |
| greeting `早安/午安/...` | client-side from local time — **no API** |

---

## 6. Build order (suggested)

1. **Auth + users + `track`/settings** → unblocks everything.
2. **Decks + cards + packs** (incl. Write/Add card, simplified↔traditional conversion).
3. **SRS review** (FSRS, Benar/Salah mapping, `mastery` buckets) — the core loop.
4. **Tests** (MC / self / spell) + **question-count** param + session logging.
5. **Rapor** aggregation + **leaderboard** + XP/streak.
6. **Games** endpoints (tone/match/listen/speed) + **TTS audio**.
7. **Guru AI** (LLM thread + daily curriculum + PR grading).
8. **Groups** (realtime WebSocket) + scheduled sessions.
9. **Voice scoring** (pronunciation assessment service).

---

## 7. Notes / open decisions

- **FSRS thresholds** for the 4 mastery buckets need tuning against real review data — start with the §2 rule-of-thumb.
- **Distractor quality** for MC/Listening: prefer same-deck / same-level meanings so options are plausible.
- **Pinyin normalization** for spelling test: decide tolerance (tone marks optional? `ü` vs `v`/`u`?). Prototype strips diacritics & non-letters and lowercases.
- **TTS provider** + caching strategy (a lot of repeated audio).
- **Pronunciation scoring** provider (Azure vs alternatives) + cost.
- **Offline**: decks/cards/SRS should work offline on device and sync — define a sync model if required for v1.
- The two **HTML prototype files** are reference UI only; the production client is Flutter. Don't port the HTML — port the *behavior* described here.

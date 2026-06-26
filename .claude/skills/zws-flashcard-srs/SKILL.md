---
name: zws-flashcard-srs
description: Use when building ZHONGWEN SHU flashcards, decks, the FSRS scheduler, the 3 test modes (multiple choice, self-check, spelling), CSV import, downloadable material packs, or card TTS audio.
---

# ZHONGWEN SHU — Flashcards & SRS

Reference: `docs/PRD.md` §6.2, §7, §10, §12.

## Cards & dual-standard
- A card carries: custom front/back AND structured fields — `simplified`, `traditional`, `pinyin`, `zhuyin`, `meaning`, `example`, `image`, `audio_cn`, `audio_tw`.
- Display follows `track` + zhuyin toggle. Never assume one script.
- Cards may link to a shared `vocab_entries` record (master dictionary) or be fully custom.

## SRS — FSRS
- Use **FSRS** (not SM-2). Persist per-card state: `stability`, `difficulty`, `due`, `reps`, `lapses`, `last_review`, `state`.
- Scheduling runs **locally (Drift)** so review works offline; sync state to Supabase when online.
- Track a per-card **mastery** signal derived from FSRS + test results; feeds the "Praktek" grade.

## Test modes (all measure mastery)
1. **Multiple choice** — distractors drawn from same deck/level.
2. **Self-check** — flip card, user marks correct/incorrect (feeds FSRS rating).
3. **Spelling** — type hanzi or pinyin; tolerant matching for tones/spacing.
- Test source: one/many decks or random. Results update SRS + grades.

## Import & packs
- **CSV import** (simple, lightweight). Define a clear header (e.g. `simplified,traditional,pinyin,zhuyin,meaning,example,deck,tags`). Validate + preview before commit.
- **Material packs**: app ships empty; a Settings toggle downloads curated decks (HSK 1-6 / TOCFL) from Supabase Storage `material-packs`. Source open datasets; store normalized to the card schema.

## TTS audio
- Generate with **Edge-TTS** on demand, then **cache** (device + Storage `card-audio`); key cache by (text + voice). Voices: zh-CN (mainland) and zh-TW (Taiwan).
- Fallback to `flutter_tts` (OS voices) when offline.
- Never regenerate audio that's already cached.

## Build order within this subsystem
Card model + Drift → FSRS scheduler (TDD the algorithm) → review UI → test modes → CSV import → TTS+cache → material-pack download.

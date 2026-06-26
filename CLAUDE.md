# ZHONGWEN SHU (中文书) — Project Context

Mandarin learning app (Flutter) supporting **both** standards: HSK (China, 简体, pinyin) and TOCFL (Taiwan, 繁體, zhuyin). Full spec in `docs/PRD.md`. Build order in `docs/ROADMAP.md`.

## Build agent & discipline
- Built by **Claude Code (Opus 4.8)**.
- Follow **superpowers** workflow: `writing-plans` per milestone → `test-driven-development` → `verification-before-completion`. Use `systematic-debugging` for any bug.
- This repo has **project skills** in `.claude/skills/` — load the relevant one before working on a subsystem (see below).

## Stack
- **Flutter** (Windows + Android; iOS later) · **Riverpod** state.
- **Drift/SQLite** local (cards, SRS, cache, offline-first for learning).
- **Supabase**: Auth, Postgres (+RLS), Realtime, Storage, Edge Functions.
- **DeepSeek (free flash) via OpenCode Zen** for the AI teacher — always behind an Edge Function proxy.
- **Azure Speech** (pronunciation scoring), **Edge-TTS** (card audio, cached), on-device pitch (tone tuner).
- **FSRS** spaced-repetition. **Kaiti** font for hanzi.

## Non-negotiable rules
1. **Dual-standard is first-class.** Every vocab record carries 简 + 繁 + 拼音 + 注音. Never store only one. Respect the user's `track` (simplified | traditional | both) and the zhuyin on/off setting in all UI.
2. **No secrets in the client.** All LLM / Azure / service-role calls go through Edge Functions. The client only ever holds the Supabase anon key. Never send credentials/`acc.env` to the LLM.
3. **Offline-first for learning.** Flashcards/SRS must work with no network. Social/AI features may require network.
4. **Design:** distinctive but never tacky ("norak"). **No emoji in UI.** Icons = one simple lineart/solid family. See skill `zws-design-system`.
5. **Cost:** everything on free tiers. Cache aggressively (TTS audio, LLM curriculum, scoring results). Rate-limit per user server-side.

## Planned repo structure
```
/app            Flutter app (lib/, test/, windows/, android/)
/supabase       migrations/, functions/ (llm-proxy, scoring-proxy, curriculum-gen, rate-limiter)
/docs           PRD.md, ROADMAP.md, next-steps.md, SETUP.md, ui/ (mockups)
/.claude/skills project skills
```

## Project skills (load when relevant)
- **zws-design-system** — any UI/theming/component work.
- **zws-supabase-backend** — schema, RLS, auth, Edge Functions.
- **zws-llm-teacher** — AI teacher, curriculum, private/group chat, adaptivity.
- **zws-flashcard-srs** — cards, FSRS, decks, test modes, CSV import, TTS.
- **zws-voice-tone** — pronunciation scoring, tone detection, real-time tuner.

## Credentials (all server-side except Supabase anon)
Supabase (anon + service), OpenCode Zen key, Azure Speech key+region, Resend key. See `docs/SETUP.md`. Status: Azure account created.

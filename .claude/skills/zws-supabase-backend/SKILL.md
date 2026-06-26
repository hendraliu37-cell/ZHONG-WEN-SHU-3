---
name: zws-supabase-backend
description: Use when working on ZHONGWEN SHU backend — Postgres schema, migrations, RLS policies, Supabase Auth (username/numeric-ID, Resend SMTP), Realtime, Storage, or Edge Functions (llm-proxy, scoring-proxy, curriculum-gen, rate-limiter).
---

# ZHONGWEN SHU — Supabase Backend

Reference: `docs/PRD.md` §7, §8, §9, §15.

## Golden rules
- **RLS on every table.** Default deny; users access only their own rows or rooms they belong to. Write a policy test for each table.
- **Secrets live only in Edge Functions** (set via `supabase secrets set`). The client uses the **anon key** only. The **service-role key never ships to the client.**
- Schema changes go through **migrations** in `/supabase/migrations` (never ad-hoc SQL in prod). Use `list_tables`/`list_migrations` before changing schema.

## Auth & identity
- Email + password via Supabase Auth, **custom SMTP = Resend** (so confirmation emails come from the app, not Supabase).
- `profiles`: `username` (unique, free text) + `numeric_id` (unique, digits only). Enforce uniqueness with DB constraints; generate/validate `numeric_id` server-side.
- For the tens-of-testers phase, keep email confirmation on via Resend; revisit at publish.

## Edge Functions (Deno)
- **llm-proxy** — the ONLY path to DeepSeek (via OpenCode Zen, OpenAI-compatible). Authenticates the user, enforces `rate-limiter`, forwards the request, returns the completion. Never expose the key.
- **scoring-proxy** — forwards audio to Azure Pronunciation Assessment; returns per-syllable + tone scores. Cache results.
- **curriculum-gen** — generates curriculum/daily material per (level × track) **once**, stores in `materials`. Served to all users from cache; do NOT call the LLM per user for standard material.
- **rate-limiter** — per-user quota (token/req budget). On limit: degrade gracefully (serve cache / queue), never hard-crash the UI.

## Realtime & Storage
- Room chat uses Supabase Realtime (channel per room). Keep messages in `messages` with RLS by room membership.
- Storage buckets: `card-audio` (TTS cache), `card-images`, `material-packs` (downloadable decks). Public-read where safe; signed URLs otherwise.

## Checklist before shipping a backend change
1. Migration written + applied locally. 2. RLS policy + test. 3. Secrets via `supabase secrets`, not code. 4. `get_advisors` clean (security/perf). 5. Client only touches anon-safe surface.

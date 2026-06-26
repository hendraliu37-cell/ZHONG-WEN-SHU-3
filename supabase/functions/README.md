# Edge Functions — Zhongwen Shu

All secrets live server-side (Supabase → Project Settings → Edge Functions →
Secrets), never in the client and never hardcoded in function source. Set via
the dashboard or `supabase secrets set`. Values are in `acc.env`.

| Function    | Purpose                            | Required secrets | Status |
|-------------|------------------------------------|------------------|--------|
| `llm-proxy` | AI tutor (Guru) chat               | `OPENMODEL_API_KEY`, `OPENMODEL_BASE_URL`, `OPENMODEL_MODEL` | ✅ OpenModel-ready |
| `translate` | Text translate (zh↔id) + breakdown | *reuses* `OPENMODEL_*` | ✅ OpenModel-ready |
| `stt`       | Voice → text (Azure Speech)        | `AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION` | ⏳ set secrets |
| `ocr`       | Photo → text (vision chat)         | `OCR_API_KEY`+`OCR_BASE_URL`+`OCR_MODEL` (or reuses `OPENCODE_ZEN_*`) | ⚠️ needs a vision provider |

## Enable voice (`stt`) — Azure Speech (free F0, key already exists)

In the dashboard → Edge Functions → Secrets, add (values from `acc.env`):

```
AZURE_SPEECH_KEY    = <AZURE_SPEECH_KEY from acc.env>
AZURE_SPEECH_REGION = southeastasia
```

The client records 16 kHz mono WAV; the function reads the sample rate from the
WAV header and calls Azure STT (`zh-CN` / `id-ID`). Works once the secrets land.

## Enable photo (`ocr`) — needs a vision model

The configured provider (OpenCode Zen) only offers **vision models on a paid
plan** — the free models are text-only. So pick ONE:

- **Add a payment method to OpenCode Zen**, then it reuses `OPENCODE_ZEN_*` with
  a vision model (default `gemini-3-flash`). Optionally set `OCR_MODEL`.
- **Use another vision provider** by setting:
  ```
  OCR_API_KEY  = <key>
  OCR_BASE_URL = https://generativelanguage.googleapis.com/v1beta/openai  # e.g. Google Gemini (has a free tier)
  OCR_MODEL    = gemini-2.0-flash
  ```
  (any OpenAI-compatible vision endpoint works — OpenAI, Gemini, etc.)

Until then `ocr` returns a clear error and the UI shows a friendly message.

## Enable Guru + Translate AI — OpenModel DeepSeek V4 Flash

Set these as Edge Function secrets:

```
OPENMODEL_API_KEY  = <your OpenModel key>
OPENMODEL_BASE_URL = https://api.openmodel.ai
OPENMODEL_MODEL    = deepseek-v4-flash
```

`llm-proxy`, `translate`, and `group-guru` automatically use OpenModel's
Messages protocol (`/v1/messages`) when `OPENMODEL_API_KEY` is present. Legacy
`OPENCODE_*` / DeepSeek chat-completions settings still work as fallback.

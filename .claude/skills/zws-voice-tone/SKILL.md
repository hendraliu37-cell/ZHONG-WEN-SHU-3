---
name: zws-voice-tone
description: Use when building ZHONGWEN SHU voice features — pronunciation scoring (Azure), tone (1-4) detection, and the real-time guitar-tuner-style tone meter. Covers what runs on-device (free) vs via proxy (Azure free tier).
---

# ZHONGWEN SHU — Voice & Tone

Reference: `docs/PRD.md` §6.5, §10.

## Three sub-features
1. **Pronunciation scoring** — user speaks a word/sentence → per-syllable + tone accuracy score.
2. **Tone detection (1-4)** — classify the tone produced.
3. **Tone tuner (guitar-tuner style)** — real-time pitch contour vs the target tone shape.

## What runs where
- **On-device (free, offline):** the **tuner** and tone practice. Use a pitch-detection algorithm (YIN / autocorrelation) on the mic stream; map pitch over time to a contour and compare against the target:
  - Tone 1 = high & flat · Tone 2 = rising · Tone 3 = dip then rise · Tone 4 = sharp fall · neutral = light/short.
  - Visualize like a tuner: show the user's live contour over the target band; indicate match quality.
- **Cloud (Azure free tier ~5h/mo):** **pronunciation scoring** via the `scoring-proxy` Edge Function (key stays server-side). Returns per-syllable + tone scores.

## Cost discipline
- Default to the **on-device tuner** for everyday practice (free, unlimited).
- Gate Azure scoring behind explicit "score my pronunciation" actions; **cache** results; cap attempts per user/day to respect the free tier.
- Scoring results feed the **"Praktek"** grade (§11).

## Implementation notes
- Mic permission handling per platform (Windows/Android). Graceful fallback if no mic.
- Keep DSP (pitch detection) in an isolate to avoid UI jank.
- Make the target tone configurable per card/syllable so the tuner works for any vocab.

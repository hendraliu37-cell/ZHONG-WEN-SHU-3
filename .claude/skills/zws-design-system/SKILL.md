---
name: zws-design-system
description: Use when doing ANY UI, theming, layout, component, icon, or visual work in the ZHONGWEN SHU app. Encodes the non-negotiable design language (distinctive but not tacky, no emoji, lineart/solid icons, Kaiti hanzi, dual-standard display, dark/light/system).
---

# ZHONGWEN SHU — Design System

Reference: `docs/PRD.md` §13 and `docs/ui/` mockups (once the UI design phase is done).

## Hard rules (do not violate)
- **No emoji anywhere in the UI.**
- **Icons:** ONE consistent family, **lineart OR solid**, simple. No clip-art, no gradients-as-decoration, no "AI/cyberpunk/neon" vibe.
- **Not tacky ("norak"):** restrained palette, generous spacing, clear hierarchy. Distinctive and ownable — not default Material look.
- **Hanzi font: Kaiti (楷体)** for all Chinese characters. A clean modern Latin sans for UI text.
- **Themes:** Dark / Light / By System — all three must look intentional, not auto-inverted.

## Dual-standard display
- Respect `profile.track`: `simplified` → show 简; `traditional` → show 繁; `both` → show both (primary per a user-chosen default).
- Romanization: pinyin for simplified path, **zhuyin/注音** for traditional path. **Zhuyin has an on/off toggle in Settings** — honor it everywhere.
- Never hardcode one script in a widget; read from settings.

## Navigation
- Bottom tab bar, **Profile rightmost**. Proposed 5 tabs: Beranda · Belajar · Grup · Guru · Profil (final set decided in the UI design phase). Avoid 7+ bottom tabs.

## Component conventions
- Centralize theme in one place (colors, typography, spacing, radii, elevation). No magic numbers in widgets.
- Build a small reusable kit first: buttons, cards, list tiles, the hanzi card, chat bubble, tuner gauge. Reuse, don't re-style ad hoc.
- Accessibility: tap targets ≥ 48dp, sufficient contrast in both themes, scalable text.

## Before building UI
1. Confirm the screen exists in `docs/ui/` mockups; if not, align with the design system first.
2. Pull colors/typography from the theme, not literals.
3. Verify it renders in dark AND light, simplified AND traditional, zhuyin on AND off.

# omarchy-starter Design System

## 0. Research Log

- Live reference: [yelixir.dev](https://yelixir.dev) — home page and `style.css` inspected on 2026-09-27 in Playwright + system Chromium at 1440x900 and 390x844. Adopted its paper/ink palette, the Space Grotesk / DM Sans / Instrument Serif italic / JetBrains Mono type system, 2/6/14px radii, pill buttons, the mono kicker with a leading rule, headings that end in an italic serif accent word, the roman-numeral list with hairline dividers, `FIG. n —` captions, and the dark grain hero with a gold kicker. Its imagery (the soap-film sphere, film canvas, shorts, bench screenshots) is not copied.
- StyleGallery: `recipes/article-page.md` (content-limiter + sticky-aside + stack). The document owns scrolling; the table of contents is a sticky aside on desktop and falls into normal flow under 820px.
- Fonts: the four yelixir.dev WOFF2 files (SIL OFL 1.1), re-subset with `pyftsubset` to Latin, punctuation, and arrows. JetBrains Mono's `calt`/`liga` ligatures are removed so code shows the literal characters a beginner has to type. Box-drawing glyphs (U+2500-257F, U+2713) are subset from upstream JetBrains Mono (OFL) for the installer terminal mock.
- Skipped lanes: Lazyweb and Imagen concept drafts. A concrete live reference was supplied, so neither real-product harvesting nor concept drafts would change the direction.

## 1. Atmosphere & Identity

A warm field manual from the yelixir.dev family. The page opens on a dark, grain-textured ink hero with a gold kicker, then turns to warm paper where every chapter reads like a lab notebook entry: a mono kicker, a large grotesk heading that ends in an italic serif word, short prose, and commands set on dark ink plates.

The signature is the **ink plate**. The one-line installer in the hero, every copyable command, and the installer's terminal-screen mock share the same dark material, so the guide reads as paper notes around real terminals. The moment a visitor remembers is the installer screen mock: a typeset TUI (not a screenshot) that shows every choice in one frame.

Primary persona: a new Omarchy user who can paste a command but does not yet know agent CLIs, Fcitx, libinput, or NetworkManager. A secondary persona is an Intel Mac owner diagnosing Apple-specific hardware. English readers get a sibling page with the same structure. The page must stay useful with the keyboard, at 200% zoom, with reduced motion, and on narrow viewports.

## 2. Color

| Role | Token | Value | Usage |
|------|-------|-------|-------|
| Ink / deepest | `--ink-950` | `#0e0c0a` | Hero base, footer |
| Ink / plate | `--ink-900` | `#15120f` | Code blocks, hero command plate |
| Ink / raised | `--ink-850` | `#1b1714` | Terminal card, copy button on dark |
| Ink / text | `--ink-700` | `#28231f` | Headings and strong text on paper, strong rules |
| Hero glow 1 | `--glow-1` | `#2b231c` | Hero radial gradient inner stop |
| Hero glow 2 | `--glow-2` | `#17130f` | Hero radial gradient middle stop |
| Cream | `--cream` | `#f1ede5` | Text on dark |
| Cream 2 | `--cream-2` | `#cbc2b4` | Secondary text on dark |
| Cream 3 | `--cream-3` | `#a69b8c` | Tertiary text on dark: captions, dim TUI text |
| Gold | `--gold` | `#e5b45b` | Accent on dark: kicker, hero accent word, focus ring on dark |
| Teal lit | `--teal-lit` | `#7fb8bb` | Secondary accent on dark: prompt marks, "keep" state |
| Paper | `--paper` | `#f1ede5` | Page background |
| Paper 2 | `--paper-2` | `#ebe5da` | Step cards (plates) |
| Paper high | `--paper-hi` | `#f7f4ee` | Inline code, TOC, note callouts, table headers |
| Line | `--line` | `#d2cbc0` | Hairline dividers |
| Body | `--body` | `#5c544a` | Body text on paper |
| Muted | `--muted` | `#6b6258` | Captions, secondary text |
| Rust | `--rust` | `#9f4d2e` | Accent on paper: links, focus, labels, accent word, warnings |
| Teal deep | `--teal-deep` | `#1d6a72` | Secondary on paper: "AI에게 맡기기" prompt label |
| Rust wash | `--rust-wash` | `#efe5dd` | Warning callout surface (rust 9% over paper-hi) |
| Teal wash | `--teal-wash` | `#e6e9e4` | AI prompt plate surface (teal-deep 8% over paper-hi) |
| Hair dark | `--hair-dark` | `rgb(241 237 229 / 12%)` | Hairlines on dark |

Measured WCAG contrast (all text pairs pass AA 4.5:1): body/paper 6.37, body/paper-2 5.94, muted/paper-2 4.77, rust/paper 5.03, rust/paper-2 4.69, rust/rust-wash 4.73, teal-deep/teal-wash 5.11, cream-3/ink-900 6.83, gold/ink-950 10.24, teal-lit/ink-900 8.42.

Rules:
- Rust is the only accent on paper; gold is the only accent on dark. Teal marks the AI prompt plate and nothing else on paper.
- Warnings use the rust wash plus a text label and a triangle glyph. Notes use paper-hi plus a label and an info glyph. Meaning never relies on color alone.
- State is encoded with ink-alpha washes and glyphs. No component uses a colored side border to mark state or tone; focus-visible rings are the only colored edge.
- No green. The previous green palette is retired.

## 3. Typography

| Role | Token | Stack |
|------|-------|-------|
| Display | `--f-display` | "Space Grotesk", "Pretendard", "Noto Sans KR", "Noto Sans CJK KR", system-ui, sans-serif |
| Body | `--f-body` | "DM Sans", "Pretendard", "Noto Sans KR", "Noto Sans CJK KR", system-ui, sans-serif |
| Accent serif | `--f-serif` | "Instrument Serif", "Noto Serif KR", "Noto Serif CJK KR", "AppleMyungjo", "Batang", Georgia, serif |
| Mono | `--f-mono` | "JetBrains Mono", "D2Coding", "Noto Sans Mono CJK KR", "Pretendard", "Noto Sans KR", "Noto Sans CJK KR", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace |

The Latin fonts are embedded as base64 WOFF2 in each HTML file. Hangul always comes from the Korean fallbacks.

| Level | Token | Size | Weight | Line height | Usage |
|-------|-------|------|--------|-------------|-------|
| Hero | `--fs-hero` | clamp(2.75rem, 1.4rem + 5vw, 5.75rem) | 500 | 0.98 (ko 1.08) | Page title |
| Chapter | `--fs-chapter` | clamp(2rem, 1.3rem + 2.4vw, 3.25rem) | 500 | 1.06 (ko 1.16) | Chapter h2 |
| H3 | `--fs-h3` | clamp(1.3rem, 1.1rem + 0.6vw, 1.625rem) | 500 | 1.2 | Step card titles |
| H4 | `--fs-h4` | 1.125rem | 600 | 1.35 | Troubleshooting questions, table groups |
| Lead | `--fs-lead` | clamp(1.125rem, 1rem + 0.4vw, 1.3rem) | 400 | 1.6 | Hero and chapter lead |
| Body | `--fs-body` | 1.0625rem (1rem under 720px) | 400 | 1.72 | Prose |
| Small | `--fs-small` | 0.9375rem | 400 | 1.6 | Captions, table cells, footer |
| Code | `--fs-code` | 0.875rem | 400 | 1.65 | Code blocks, inline code, key caps |
| Label | `--fs-label` | 0.75rem | 500 | 1.3 | Mono kickers, step labels, FIG numbers, badges |

Rules:
- Headings use Space Grotesk 500 with negative tracking (-0.03em chapter, -0.035em hero) and `text-wrap: balance`.
- Accent words (`h1 em`, `h2 em`) use `--f-serif` italic in rust on paper and gold in the hero. Hangul in an accent word renders in an upright Korean serif (`font-synthesis: weight` disables fake italics), which keeps the serif contrast without slanted Hangul.
- Labels are JetBrains Mono uppercase with `--track-label`: 0.14em in English, 0.06em in Korean.
- Korean text uses `word-break: keep-all` and `overflow-wrap: break-word`. Inline code and URLs may break anywhere.
- Code turns ligatures off (`font-variant-ligatures: none`) in addition to the subset removing them.
- Body text never goes below 15px; only mono labels use 12px.

## 4. Spacing & Layout

Base unit 4px: `--space-1` 4px, `--space-2` 8px, `--space-3` 12px, `--space-4` 16px, `--space-5` 20px, `--space-6` 24px, `--space-8` 32px, `--space-10` 40px, `--space-12` 48px, `--space-16` 64px, `--space-20` 80px, `--space-24` 96px.

- Gutter: `--gutter` clamp(20px, 5vw, 72px).
- Content width: `--content-width` 72rem. Guide grid: article `minmax(0, 1fr)` plus `--aside-width` 15rem, gap `--space-16`.
- Reading measure: `--measure` 42rem for prose inside cards and chapter intros.
- Hero: two columns (copy 7fr, command plate 5fr) above 64rem, one column below.
- Breakpoints: 64rem (hero columns), 51.25rem / 820px (guide becomes one column, TOC becomes a normal block before the article), 45rem / 720px (body 16px, compact card padding).
- Scroll ownership: the document scrolls. The TOC is sticky and declares `overflow-y: auto` with a viewport-bounded `max-block-size`, so it scrolls on its own only when a short viewport cannot show it. Code blocks, tables, and the terminal card scroll horizontally inside themselves; the page never scrolls sideways.

## 5. Components & States

- **Site bar**: brand wordmark plus the language switch inside the hero. The switch is a `nav` with two links (`한국어`, `English`) carrying `lang` and `hreflang`; the current page's link has `aria-current="page"` and a cream wash pill, the other link is underlined. Hover: wash. Focus: 2px gold ring.
- **Hero**: dark atmosphere (Section 6), gold kicker, title with an accent word, lead, hero note with the `omarchy update` reminder, two pill buttons, the command plate (FIG. 0), and a mono fact rail (tested version, latest version, update first, undo included).
- **Pill button**: primary (cream fill, ink text, gold glow) and ghost (1px cream inset ring). Min height 48px. Hover: 1px lift and a brighter fill or wash. Active: scale 0.98. Focus: gold ring. These are the only links without underlines.
- **Kicker**: mono uppercase label preceded by a 24px rule, `—— 02 · 필수 — 한국어 입력`. Rust on paper, gold on dark.
- **Badge**: text pills for chapter status. 필수/Required = ink fill with paper text; 권장/Recommended = rust inset ring with rust text; 선택/Optional = line inset ring with muted text. The text carries the meaning.
- **Chapter header**: kicker, h2 with accent word, lead paragraphs within `--measure`, a hairline below. Each chapter is a `section` with an `id`.
- **Route list** (overview): an ordered list with a strong top rule and hairline row dividers. Each row has an italic serif numeral in rust, a title plus badge, a one-line outcome, and a link. The row changes nothing on hover; the link carries the affordance.
- **Roman checklist**: an ordered list with italic serif roman numerals (`i.`-`x.`) and hairline dividers. Used for chapter 00.
- **Step card (plate)**: paper-2 surface, 6px radius, plate depth (Section 6), a mono step label in rust, an h3, and prose plus code. Padding `--space-8`, `--space-6` under 720px.
- **Code block**: `pre > code` on ink-900, cream text, 6px radius, internal horizontal scroll. JavaScript adds a copy button only when the Clipboard API exists. States: idle `복사`/`Copy`, copied (`data-state="copied"`, gold ring and label for 2s, announced through a polite live region), failed (label reads that copying failed). Without JavaScript the block is plain, copyable text.
- **Command plate**: the hero's ink plate with a mono title bar and one command that wraps instead of scrolling.
- **Prompt plate** ("AI에게 맡기기"): teal-wash surface, teal-deep label with a chat glyph, and a dark code block whose text wraps (prompts are prose).
- **Callout**: warn (rust wash, triangle glyph, rust label) and note (paper-hi plus hairline, info glyph, ink label). No side stripes.
- **Terminal card**: an ink-850 figure that typesets the installer screen in JetBrains Mono. Rows are block elements; the status column is a fixed `ch` width so Hangul and Latin rows line up. The highlighted row uses a gold wash and a `>` marker; `[v]` is gold, `[-]` is teal-lit, `[ ]` is cream-3. It is followed by a `FIG. n —` caption.
- **Data table**: the legend and the item list. Hairline rows, mono uppercase header labels on paper-hi, row groups (`tbody` with a `th scope="rowgroup"`) for 필수/권장/선택. It scrolls inside its wrapper if a narrow viewport cannot fit it.
- **Figure**: embedded screenshot (data URI, bordered, 6px radius) plus a caption with a mono `FIG. n —` label and a sentence.
- **Table of contents**: a sticky `aside` with a `nav`, a mono label, numbered chapter links, and indented sub-links. The current chapter gets `aria-current="location"`, an ink wash, and a dot glyph (progressive enhancement through IntersectionObserver). Links are underlined on hover and focus.
- **Key cap**: `kbd` on paper-hi with a hairline and a 1px bottom inset.
- **Footer**: ink-950 with a hairline top, the project line, source link, credits (minsoft1115/omarchy-setup inspiration, OFL fonts, yelixir.dev), all links underlined.

Every interactive element has a visible 2px focus outline with a 3px offset (rust on paper, gold on dark). Links in prose, the TOC, and the footer stay underlined.

## 6. Depth & Material

Strategy: mixed. The paper is flat; plates and ink carry depth.

- **Plate** (step cards): `inset 0 0 0 1px rgb(40 35 31 / 8%)`, `inset 0 1px 0 rgb(255 255 255 / 60%)`, `0 30px 60px -40px rgb(70 45 20 / 45%)`.
- **Ink plate** (code, command plate, terminal): ink-900/850 fill, `inset 0 0 0 1px rgb(241 237 229 / 6%)`. The hero command plate and the terminal card add `0 30px 60px -30px rgb(0 0 0 / 55%)` plus a gold ambient `0 0 80px -30px rgb(229 180 91 / 25%)`.
- **Hero atmosphere**: `radial-gradient(90% 80% at 72% 42%, var(--glow-1) 0%, var(--glow-2) 46%, var(--ink-950) 100%)` with an SVG fractal-noise grain at 7% opacity in overlay blend.
- **Radii**: `--r-1` 2px (inline code, key caps), `--r-2` 6px (cards, code, figures, callouts), `--r-3` 14px (hero command plate, terminal card), `--r-pill` 999px (buttons, badges, language switch).

## 7. Motion

Tokens: `--t-fast` 160ms, `--t-base` 260ms, `--ease-out` cubic-bezier(0.22, 1, 0.36, 1).

- The hero copy enters once on load (opacity 0.12 to 1, 18px rise, 1s, 80ms stagger). This is the page's one signature moment.
- Pill buttons lift 1px on hover and press to scale 0.98. The copy button changes label and ring when it copies. The TOC current marker changes background only.
- Smooth anchor scrolling, the entrance, and the button transforms exist only under `prefers-reduced-motion: no-preference`. With reduced motion everything renders in its final state and state changes are instant.
- Only `transform`, `opacity`, and color properties animate.

## 8. Responsive, Accessibility & Debt

- Semantic landmarks: header (hero), nav (language switch, TOC), main, article, aside, footer.
- Document language: `lang="ko"` on the Korean page and `lang="en"` on the English page. Language links carry `hreflang`, and `<link rel="alternate" hreflang>` pairs the two files.
- A skip link appears on keyboard focus and targets `#main-content`.
- The table of contents is first in source and keyboard order inside `main`. On desktop it is placed to the right as a landmark-first shortcut; under 820px it becomes a normal block before the article.
- Every chapter shows a text badge (필수/권장/선택, Required/Recommended/Optional), and optional chapters say they can be skipped.
- Hardware-specific instructions name the tested model and explain that model identifiers are more reliable than marketing years.
- Code, tables, and the terminal card scroll inside themselves. The page has no horizontal overflow at 390px, and at 200% zoom the layout becomes one column with nothing lost.
- WCAG 2.2 AA target: contrast values in Section 2, visible focus on every interactive element, full keyboard reach, `prefers-reduced-motion` respected (Section 7).
- Accepted debt:

| Item | Location | Why accepted | Exit |
|------|----------|--------------|------|
| No hosted canonical URL or social preview image | both HTML files | The Pages URL is not final | Add when the Pages site is published |
| Fonts are embedded twice (about 106KB base64 per file) | both HTML files | Each file must work alone when shared | Revisit if a shared stylesheet becomes acceptable |
| Hangul accent words depend on a locally installed Korean serif | h1/h2 `em` | Korean serif fonts are too large to embed | Falls back to the default serif; still upright and rust |
| Terminal-mock rule lines can end up to 1ch short | terminal card | Browser Hangul advance is not exactly two terminal cells | Cosmetic only; rows stay aligned through fixed-width columns |

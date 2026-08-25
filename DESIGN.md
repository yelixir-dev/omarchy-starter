# doc-newbie Design System

## 0. Research Log

- Embedded refs: shortlisted Notion, Mintlify, Claude -> picked Minimalist + Mintlify because a first-install guide needs editorial calm, visible code, and documentation-grade hierarchy.
- Lazyweb: 1 query for desktop installation documentation, 0 screens viewed -> the endpoint returned metadata but this session had no compliant image-viewing path, so no visual details were copied.
- StyleGallery: adopted `sticky-aside` for a long guide with a persistent table of contents; the document owns scrolling and the aside collapses into ordinary flow on narrow screens.
- Imagen drafts: skipped because no image-generation tool is available in this session.

## 1. Atmosphere & Identity

A calm first-day field manual for someone configuring Omarchy for the first time. The signature is a vertical setup journey: optional and required chapters alternate with compact terminal cards, so every command stays close to its reason and the whole page reads as one finishable route rather than unrelated notes.

Primary persona: a new Omarchy user who can paste a command but does not yet know agent CLIs, Fcitx, libinput, or NetworkManager terminology. A secondary persona is an Intel Mac owner diagnosing Apple-specific hardware behavior. The page must remain useful under keyboard navigation, browser zoom, reduced motion, and narrow viewports.

## 2. Color

- `--canvas`: `#f7f6f2`
- `--surface`: `#ffffff`
- `--surface-soft`: `#eef5ef`
- `--ink`: `#18201b`
- `--ink-muted`: `#5e6861`
- `--line`: `#dfe5df`
- `--accent`: `#177449`
- `--accent-strong`: `#0d5735`
- `--code-bg`: `#132019`
- `--code-ink`: `#edf8f0`
- `--warning-bg`: `#fbf3db`
- `--warning-ink`: `#71510a`
- `--focus`: `#177449`

Green is reserved for progress, links, and focus. Warnings use amber only. Text never relies on color alone.

## 3. Typography

- Display and headings: `ui-serif`, `Georgia`, serif.
- Body and controls: `ui-sans-serif`, system UI, sans-serif.
- Code and key labels: `ui-monospace`, `SFMono-Regular`, `Consolas`, monospace.
- Scale: 12, 14, 16, 18, 24, 36, 40, 56 CSS pixels.
- Body line height: 1.7. Heading line height: 1.1-1.3.
- Reading measure: 72 characters.

## 4. Spacing & Layout

- Base unit: 4px.
- Scale: 4, 8, 12, 16, 24, 32, 48, 64, 96px.
- Maximum page width: 1120px.
- Landing overview: four sequential journey cards, one per setup chapter.
- Guide grid: flexible content column plus 240px sticky aside.
- The browser document owns scrolling; no nested scroll containers.
- Below 820px, the aside becomes a normal block before the article.

## 5. Components & States

- **Step card**: numbered heading, explanation, optional command block. Default and completed visual states are represented without interaction.
- **Journey card**: chapter number, required/optional badge, outcome, and anchor link. Required and optional states use text labels in addition to color.
- **Chapter divider**: a numbered chapter heading that introduces one independent setup topic while preserving the page-wide sequence.
- **Code block**: dark high-contrast surface, horizontally scrollable only when required, always accompanied by context.
- **Callout**: warning or success tone with a text label, never color alone.
- **Compatibility note**: states tested hardware, recommended model range, and the exact detection command before an installer is offered.
- **Table of contents**: semantic navigation with visible hover and `:focus-visible` states.
- **Key cap**: compact `<kbd>` treatment for `Ctrl + Space`.
- **Checklist**: plain semantic list with short verification outcomes.

All interactive elements require a visible 2px focus outline with 2px offset. Links remain underlined.

## 6. Depth & Material

The page is paper-like: borders and tonal shifts create hierarchy. Cards use a single low-opacity ambient shadow; code blocks are the only high-contrast material. No gradients, glass effects, or decorative animation.

## 7. Motion

No scripted motion. Hover and focus changes use color and outline only. `prefers-reduced-motion` therefore requires no alternate behavior.

## 8. Responsive, Accessibility & Debt

- Semantic landmarks: header, nav, main, article, aside, footer.
- Korean document language is declared with `lang="ko"`.
- Skip link appears on keyboard focus.
- The table of contents is first in source and keyboard focus order. On desktop it is visually placed to the right as a landmark-first shortcut; on narrow screens it appears before the article.
- Every optional chapter explicitly says it may be skipped without blocking the required Korean-input chapter.
- Hardware-specific instructions name their tested model and explain that model identifiers and controller generations are more reliable than marketing years.
- Code can wrap or scroll without widening the page.
- At 200% zoom, the layout becomes one column without lost content.
- Accepted debt: no hosted canonical URL or social preview image exists yet; add them when this folder becomes a GitHub Pages site.

# Design System

Source of truth: the HTML prototype at `Downloads/Antigua Business Map.html`.
Tokens below are ported 1:1 from its `:root` block. When the prototype changes,
change these files in the same commit.

## Type

Three families, matching the prototype's CSS variables.

| Token | Family | Used for |
| --- | --- | --- |
| `--f-display` | Gabarito | Business names, screen headings, page titles |
| `--f-body` | Hanken Grotesk | Body copy, buttons, chips, labels |
| `--f-mono` | IBM Plex Mono | KPI numbers, scores, review counts, menu prices, section labels |

Why mono is not decorative: KPIs, review counts, menu prices and ranking scores
all render in columns, and they need tabular figures or the numbers jitter
between builds. `AppText.numeric` sets `FontFeature.tabularFigures()` for this.

## Colour

Light and dark both ship, ported from the prototype. Read via `context.palette`,
which reads the `AppPaletteTheme` extension — do not reference `AppColors`
directly in a widget.

| Role | Light | Dark | Used for |
| --- | --- | --- | --- |
| `app` | `#F6F9F8` | `#0B1B22` | Screen background |
| `surface` | `#FFFFFF` | `#112630` | Cards, sheets, tab bar |
| `ink` | `#0E2530` | `#E6F0F0` | Primary text, primary buttons |
| `muted` | `#576D75` | `#8CA6AE` | Secondary text |
| `line` | `#D2DDDB` | `#23414B` | Borders, dividers |
| `red` | `#CE1126` | `#F0475B` | Antigua flag red. Accent, selected tab, premium pins |
| `gold` | `#F0B323` | `#F5BE2E` | Premium badge, star ratings, selected pin ring |
| `blue` | `#0B5FA5` | `#5BB0F0` | Links, focus ring, search priority |
| `good/warn/bad` | — | — | Status pills and banners |

Map fills (`sea`, `shallow`, `land`, `landLine`, `road`) are defined but
currently unused — the prototype hand-draws the island as SVG rather than using
a tile layer. See open questions.

## Spacing

One 4pt scale in `app_spacing.dart`. If a number is not on the scale, it does
not go in the app. Values come from the prototype's CSS.

Radii: 6 / 8 / 10 / 12 / 14 / pill. The prototype uses 10 for inputs and
buttons, 14 for cards.

## Elevation

`Shadows.card` is the prototype's `--shadow`: a tight 1px contact shadow plus a
wide 40px ambient one with negative spread. `Shadows.overlay` is the 3px blur
used for controls floating over the map — cards do not float without both, but
map chrome uses the tight one because a big shadow over the sea fill looks
wrong.

## Categories

Eight, with the prototype's hues. Hues drive the icon tile gradient and the map
pin tint, so a business's industry is recognisable before you read a word.

| Category | Hue |
| --- | --- |
| Food & drink | 18 |
| Salons & beauty | 330 |
| Trades | 42 |
| Medical | 165 |
| Tourism | 200 |
| Retail | 272 |
| Professional | 222 |
| Online-only | 95 |

`Online-only` is map-less: no walk-in location, so it appears in list results
but never as a pin.

## Tier colours

- Basic pin: category hue, dark `#0E2530`
- Premium pin: flag red `#CE1126`
- Trial pin: gold `#F0B323`

## Open questions

1. **Custom pins.** The prototype hand-draws its pins. The app currently uses
   hue-tinted default markers, because custom glyph pins need a Google Maps map
   ID enabled and are unforgiving at small sizes. Decide once pins can be
   judged on a real phone in daylight.
2. **Hand-drawn map.** The prototype draws Antigua as SVG instead of using
   Google tiles. This looks distinctive and costs nothing, but it cannot pan,
   zoom to street level, or show a user's position. Real map + our styling is
   the other option. This is a significant fork and should be settled before
   Phase 3.
3. **Fonts.** The prototype loads Gabarito, Hanken Grotesk and IBM Plex Mono
   from a web font. The app declares the family names but has no font files
   bundled yet, so it falls back to system fonts. Bundle them before Phase 10 —
   the type is a large part of the app not looking generic.
# Design System — Lubowa Sports Park

Reference: [lubowasportspark.com](https://lubowasportspark.com). Align visuals and copy (activities, hours, contact) with the website.

**Taglines:** "Play • Train • Compete" / "Sports • Fitness • Community" — modern, clean, sporty.

---

## Logo and app icon

- **Asset:** Lubowa Sports Park shield logo (green/blue crest with "LUBOWA" and "SPORTS PARK").
- **Usage:** In-app logo (splash, header, about); app icon for Android and iOS.
- **Location:** `assets/logo.png` (or equivalent). Generate platform icon sets from this asset (e.g. `flutter_launcher_icons`).
- **Do not** stretch or change aspect ratio; use on solid or brand background for contrast.

---

## Colors

| Role | Hex | Usage |
|------|-----|--------|
| Primary (green) | `#2E7D32` | App bar, primary buttons, key CTAs |
| Primary light | `#4CAF50` | Highlights, links, secondary emphasis |
| Secondary (teal/blue) | `#00897B` | "Book Now" style buttons, accents |
| Water / accent blue | `#03A9F4` | Accents, cards, water motif from logo |
| Surface | `#FFFFFF` | Cards, sheets, background |
| Background | `#F5F5F5` | Page background |
| On primary | `#FFFFFF` | Text and icons on primary/secondary |
| On surface | `#212121` | Primary text |
| On surface variant | `#757575` | Secondary text, captions |
| Outline / border | `#E0E0E0` | Dividers, borders |

Use greens as primary; blues for secondary and accent. Avoid ad-hoc colors; extend this palette only when necessary.

---

## Typography

- **Font family:** Prefer a single family for UI (e.g. **Roboto** on Android, **SF Pro** on iOS via system, or a Google Font such as **Poppins** or **Open Sans** for cross-platform consistency). Define in `ThemeData` and use consistently.
- **Scale (logical):**
  - Headline (splash, section): 24–28sp, bold
  - Title (screen title, card title): 20sp, semi-bold
  - Body: 16sp, regular
  - Body small / caption: 14sp, regular or medium
  - Label / button: 14–16sp, medium
- **Hierarchy:** Clear title → body → caption; avoid long blocks without structure.

---

## Spacing and layout

- **Base unit:** 8px (e.g. 8, 16, 24, 32).
- **Screen padding:** 16–24 horizontal; 16–24 top/bottom as needed.
- **Card padding:** 16; gap between cards 12–16.
- **List item height:** Min 56 for tappable rows; use consistent leading/trailing padding.

---

## Components

- **Buttons:** Primary = filled (primary green or teal); secondary = outlined. Min tap target 48dp. Use consistent border radius (e.g. 8).
- **Cards:** Elevation or border; 8–12 radius; use surface color.
- **App bar:** Primary color; white title and actions; optional logo in header.
- **Forms:** Clear labels; error state and validation feedback; consistent padding.

---

## ThemeData (Flutter)

- Set `ColorScheme` from the palette above (primary, secondary, surface, background, onPrimary, onSurface, etc.).
- Set `textTheme` from the typography scale.
- Use `Theme.of(context).colorScheme` and `Theme.of(context).textTheme`; avoid hardcoded colors in UI.

---

## Conventions

- No placeholder "Lorem ipsum" in production; use real copy or clear labels.
- Platform: Material or Cupertino used consistently; match platform conventions where it helps (e.g. back navigation, bottom nav).
- Follow this doc for all new screens and components; update the doc when the brand evolves.

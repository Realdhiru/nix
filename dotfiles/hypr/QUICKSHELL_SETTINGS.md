# QuickShell Settings Reference (`~/.config/hypr/settings.json`)

All QuickShell visual controls are centralized in `~/.config/hypr/settings.json`.
Changes take effect **instantly** via native C++ inotify file watchers without requiring any bash processes or shell restarts.

---

## 1. Palette Tokens Available
Every color option below accepts any of these tokens extracted dynamically from your wallpaper by Wallust:

| Token | Description | Wallust Dark Default |
| :--- | :--- | :--- |
| `"primary"` | Dominant harmonic accent scored by saturation/luminance | Dynamic wallpaper amber/gold/accent |
| `"mauve"` | Secondary harmonic accent | Dynamic wallpaper midtone |
| `"text"` | Primary foreground text (soft warm ivory, decoupled from ANSI red) | `#EDE6DC` |
| `"subtext0"` | Secondary text for dates, subtitles, hints | `#C9BFB5` |
| `"subtext1"` | Muted tertiary text | `#A89F95` |
| `"base"` | Deep background tone | Extracted dark tone (`#110D0B`) |
| `"mantle"` | Darker layer background | Extracted dark tone |
| `"crust"` | Deepest shadow tone | `#080605` |
| `"surface0"` | Low-contrast card background | Dark surface tone |
| `"surface1"` | Medium-contrast pill/button background | Elevated surface tone |
| `"surface2"` | High-contrast pill/button hover tone | Elevated hover tone |
| `"overlay0"` | Subtle icon/accent border | Midtone gray |
| `"overlay1"` | Bright icon/accent border | Light gray |
| `"blue"` | Blue accent | Extracted sky/cool accent |
| `"sapphire"` | Sapphire blue | Deep cool tone |
| `"peach"` | Warm peach/orange | Warm midtone |
| `"yellow"` | Warm yellow/gold | Bright accent |
| `"teal"` | Cyan/teal | Botanical/cool accent |
| `"green"` | Botanical green | Foliage accent |
| `"red"` | Warning/alert tone | Warm red accent |
| `"glass"` | Pure specular white highlight (`Qt.rgba(1, 1, 1, alpha)`) | Liquid glass reflection |

---

## 2. Appearance Keys in `settings.json`

```json
{
  "themeMode": "dark",
  "popupBackgroundSource": "base",
  "popupOpacity": 0.20,
  "cardColorSource": "glass",
  "cardOpacity": 0.04,
  "topbarColorSource": "surface1",
  "topbarPillOpacity": 0.35,
  "topbarPillHoverOpacity": 0.60,
  "clockColorSource": "text",
  "textColorSource": "text",
  "accentColorSource": "primary",
  "borderWidth": 1,
  "borderOpacity": 0.08,
  "glassSpecular": 0.04
}
```

### Options Breakdown

### A. Theme Mode
- **`themeMode`**: `"dark"` | `"light"`
  - Permanently defaults to `"dark"`. Light wallpapers will **never** automatically force light mode.

### B. TopBar Pills
- **`topbarColorSource`**: `"surface1"` | `"surface0"` | `"base"` | `"glass"` | `"mantle"`
  - Chooses which palette tone tints the TopBar pills.
- **`topbarPillOpacity`**: `0.0` (fully transparent) to `1.0` (solid).
  - Recommended: `0.30` - `0.45` for liquid glass.
- **`topbarPillHoverOpacity`**: `0.0` to `1.0`.
  - Recommended: `0.55` - `0.70` for responsive hover feedback.
- **`cavaGradient`**: `"soft"` | `"warm"` | `"ivory"` | `"sapphire"`
  - Controls CAVA visualizer vertical gradient style:
    - `"soft"` (default): Monochromatic luminescent intensity fade (delicate 0.35 alpha at base rising to 1.0 vibrant accent at peaks). Completely avoids muddy middle-color collisions.
    - `"warm"`: Sunset fade between warm peach/mauve and primary accent.
    - `"ivory"`: Clean transition from warm ivory `subtext0` at base to primary accent at peaks.
    - `"sapphire"`: Cool sapphire blue at base to primary accent at peaks.

### C. Popups & Cards
- **`popupBackgroundSource`**: `"base"` | `"mantle"` | `"crust"` | `"surface0"`
  - Background tone of open popup windows (Calendar, Music, Network, Battery).
- **`popupOpacity`**: `0.0` (pure glass) to `1.0` (solid opaque).
  - Recommended: `0.15` - `0.25` for liquid glass blur.
- **`cardColorSource`**: `"glass"` | `"surface0"` | `"surface1"` | `"base"`
  - Inner card container tint. Set to `"glass"` for pure specular liquid glass sheen, eliminating black card boxes.
- **`cardOpacity`**: `0.0` to `1.0`.
  - Recommended: `0.04` (liquid glass sheen) up to `0.20`.

### D. Typography & Clock
- **`clockColorSource`**: `"text"` | `"primary"` | `"mauve"` | `"subtext0"` | `"peach"` | `"yellow"` | `"auto"`
  - Determines the color of the big clock digits and TopBar clock.
  - Set to `"text"` for soft warm ivory (`#EDE6DC`).
  - Set to `"primary"` for dynamic harmonic wallpaper accent.
  - Set to `"auto"` for time-of-day dynamic shift (morning peach, midday sapphire, evening mauve).
- **`textColorSource`**: `"text"` | `"subtext0"` | `"subtext1"`
  - Determines standard label and header text color.
- **`accentColorSource`**: `"primary"` | `"mauve"` | `"blue"` | `"peach"` | `"teal"` | `"auto"`
  - Sets active workspace pill highlight, slider fills, today's calendar highlight, and active indicators.

### E. Borders & Hairlines
- **`borderWidth`**: `0` (frameless) | `1` (clean hairline) | `2`
- **`borderOpacity`**: `0.0` (no border) to `0.30` (strong border). Recommended: `0.08` for liquid glass edge specular reflection.
- **`glassSpecular`**: `0.02` to `0.10`. Specular highlight intensity for liquid glass cards.

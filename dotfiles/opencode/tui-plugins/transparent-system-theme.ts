// Transparency for the root background, backgroundPanel, backgroundElement and
// diffContextBg is now expressed in the generated theme itself as the literal
// "none", which theme/index.ts:246 resolves to RGBA.fromInts(0,0,0,0). That is
// deliberate: the theme JSON has no alpha channel, but "none" is a supported
// value, and it is applied by resolveTheme() at construction time. Doing it here
// instead was never reliable - the objects handed to plugins go through a
// get-only Proxy (context/theme.tsx:275) and are replaced wholesale every time
// the values() memo re-runs, so any post-hoc write was either discarded or
// reverted within a frame.
//
// That leaves exactly one job here that theme data cannot express: the +/- diff
// row fills need PARTIAL alpha (WASH_ALPHA), and the theme format has no way to
// say that. Everything else in this file used to be surface transparency.
const DIFF_KEYS = ["diffContextBg"]

// Upstream generateSystem builds the +/- row backgrounds as
// tint(bg, ansiColors.green|red, 0.22), and tint() returns RGBA.fromInts(...)
// with no alpha channel. So the hue is pre-multiplied into the terminal
// background at full opacity. With this system's Wallust palette the ANSI
// green/red are near-gray (#5E5E60 / #484849) over a #000000 terminal, which
// lands on rgb(21,21,21) / rgb(16,16,16) - an opaque black bar. Rebuild these
// four from the live theme instead: a translucent wash of theme.text (the
// light Wallust foreground) carrying a whisper of the row's own diff hue so
// +/- stays distinguishable. No hardcoded colors; everything below is read
// off api.theme.current on every pass.
const WASH_KEYS = [
  "diffAddedBg",
  "diffRemovedBg",
  "diffAddedLineNumberBg",
  "diffRemovedLineNumberBg",
] as const
const WASH_HUE: Record<string, string> = {
  diffAddedBg: "diffAdded",
  diffRemovedBg: "diffRemoved",
  diffAddedLineNumberBg: "diffAdded",
  diffRemovedLineNumberBg: "diffRemoved",
}
const WASH_LIGHT_MIX = 0.34
const WASH_HUE_MIX = 0.25
const WASH_ALPHA = 0.16

type Color = { r: number; g: number; b: number; a: number }
type Theme = Record<string, Color | undefined>

export default {
  id: "transparent-system-theme",
  tui: (api: any) => {
    // generateSystem reuses one RGBA instance for several keys, so the first
    // decision for a given object is final and later writes through an alias
    // would be lost. The wash claims its keys here.
    const decided = new Set<object>()

    // Light wash of theme.text over the terminal background, then a light
    // pull toward the row's diff hue. Written straight onto the existing RGBA
    // instance; no reassignment, so every live reference sees the new value.
    const setWash = (theme: Theme, key: string) => {
      const color = theme[key]
      const base = theme.background
      const light = theme.text
      if (!color || !base || !light || decided.has(color)) return false
      decided.add(color)
      const hue = theme[WASH_HUE[key]!]
      const mix = (i: 0 | 1 | 2) => {
        const from = (base[i] ?? 0) + ((light[i] ?? 0) - (base[i] ?? 0)) * WASH_LIGHT_MIX
        if (!hue) return from
        return from + ((hue[i] ?? 0) - from) * WASH_HUE_MIX
      }
      const target = [mix(0), mix(1), mix(2)]
      // Idempotent: re-deriving the same floats must not retrigger a render.
      if (
        color.a === WASH_ALPHA &&
        Math.abs(color.r - target[0]) < 0.002 &&
        Math.abs(color.g - target[1]) < 0.002 &&
        Math.abs(color.b - target[2]) < 0.002
      )
        return false
      color.r = target[0]
      color.g = target[1]
      color.b = target[2]
      color.a = WASH_ALPHA
      return true
    }

    // Only alpha and a theme-derived RGB blend are touched: every hue still
    // comes from the live terminal palette, so Wallust/WezTerm colors keep
    // working and a wallpaper change re-derives the wash automatically.
    const apply = () => {
      const theme = api.theme.current as unknown as Theme
      decided.clear()
      let changed = false

      for (const key of WASH_KEYS) changed = setWash(theme, key) || changed

      if (changed) api.renderer.requestRender()
      return changed
    }

    apply()

    // The theme is resolved asynchronously at startup, so retry quickly until
    // it lands, then keep a slow guard for later theme rebuilds (mode switch,
    // palette refresh) that regenerate every color.
    let fast: ReturnType<typeof setInterval> | undefined = setInterval(() => {
      if (apply() && api.theme.ready && fast) {
        clearInterval(fast)
        fast = undefined
      }
    }, 100)

    const guard = setInterval(apply, 2000)
    const reapply = () => setTimeout(apply, 0)
    api.renderer.on("palette", reapply)
    api.renderer.on("theme_mode", reapply)

    api.lifecycle.onDispose(() => {
      if (fast) clearInterval(fast)
      clearInterval(guard)
    })
  },
}

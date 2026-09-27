// backgroundMenu is deliberately NOT here. It is the one panel key that is a
// floating surface rather than an inline one, so it needs its own backdrop.
const PANEL_KEYS = ["backgroundPanel", "backgroundElement"]
const DIFF_KEYS = ["diffContextBg"]
const PANEL_ALPHA = 0

// component/prompt/autocomplete.tsx:735 paints the menu with
// theme.backgroundMenu, so alpha 0 leaves it floating straight over transcript
// text and unreadable. Derive an opaque backdrop from the live theme instead: a
// light mix of theme.text over theme.background, no hardcoded RGB and no
// partial alpha. Assigned as a NEW RGBA instance rather than mutated in place,
// because generateSystem aliases these keys onto shared instances upstream -
// writing the shared object would drag backgroundPanel/backgroundElement opaque
// along with it. See the note on `decided` below.
const MENU_KEY = "backgroundMenu"
const MENU_LIGHT_MIX = 0.07

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
    // generateSystem reuses one RGBA instance for several keys, e.g.
    // backgroundPanel and diffContextBg are both grays[2]. Writing alpha
    // through the last key wins, so the first decision for a given object is
    // final. The wash runs before the panel pass so it also wins in the event
    // that a future opencode release aliases a wash key onto a panel key.
    const decided = new Set<object>()

    const setAlpha = (theme: Theme, key: string, alpha: number) => {
      const color = theme[key]
      if (!color || decided.has(color)) return false
      decided.add(color)
      if (color.a === alpha) return false
      color.a = alpha
      return true
    }

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

    // Installs a brand new RGBA instance for the menu so the panel pass above
    // can never reach it through a shared upstream reference, and so an aliased
    // backgroundPanel/backgroundElement object can never be dragged opaque with
    // it. The base RGB is snapshotted into plain numbers FIRST: this runs after
    // the panel pass, and reading theme.background/theme.text live here would
    // mix in whatever those objects were just mutated into.
    const setMenu = (theme: Theme) => {
      const src = theme.background
      const light = theme.text
      if (!src || !light) return false
      const RGBA = Object.getPrototypeOf(src).constructor
      if (typeof RGBA?.fromValues !== "function") return false
      const base = [src.r ?? 0, src.g ?? 0, src.b ?? 0]
      const lit = [light.r ?? 0, light.g ?? 0, light.b ?? 0]
      const target = [0, 1, 2].map((i) => base[i]! + (lit[i]! - base[i]!) * MENU_LIGHT_MIX)
      const current = theme[MENU_KEY]
      // Idempotent: re-deriving the same floats must not retrigger a render.
      if (
        current &&
        current.a === 1 &&
        Math.abs(current.r - target[0]!) < 0.002 &&
        Math.abs(current.g - target[1]!) < 0.002 &&
        Math.abs(current.b - target[2]!) < 0.002
      )
        return false
      const menu = RGBA.fromValues(target[0]!, target[1]!, target[2]!, 1)
      theme[MENU_KEY] = menu
      decided.add(menu)
      return true
    }

    // Only alpha and a theme-derived RGB blend are touched: every hue still
    // comes from the live terminal palette, so Wallust/WezTerm colors keep
    // working and a wallpaper change re-derives the wash automatically.
    const apply = () => {
      const theme = api.theme.current as unknown as Theme
      const system = api.theme.selected === "system" && theme.background?.a === 0
      decided.clear()
      let changed = false

      for (const key of WASH_KEYS) changed = setWash(theme, key) || changed
      if (!system && theme.background && theme.selectedListItemText !== theme.background) {
        changed = setAlpha(theme, "background", PANEL_ALPHA) || changed
      }
      for (const key of PANEL_KEYS) changed = setAlpha(theme, key, PANEL_ALPHA) || changed
      // diffContextBg aliases backgroundPanel upstream, so this is normally a
      // no-op; kept so the context rows stay fully transparent even if a
      // future opencode release decouples the two.
      for (const key of DIFF_KEYS) changed = setAlpha(theme, key, PANEL_ALPHA) || changed
      // Last, so it cannot be flattened by the panel pass above.
      changed = setMenu(theme) || changed

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

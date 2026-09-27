type Color = { r: number; g: number; b: number; a: number }
type Any = any
type Patched = ((...args: Any[]) => Color) & { transparentBackdrop?: boolean }

// component/logo.tsx:10 -> tint(theme.background, fg, 0.25), used as bg= on the
// "_" and "^" logo cells (logo.tsx:15,22). tint() in context/theme.tsx:346
// returns RGBA.fromInts(r, g, b) with no alpha, so that shadow is always
// opaque and paints black rectangles inside the logo.
const LOGO_SHADOW_MIX = 0.25

export default {
  id: "transparent-overlays",
  tui: (api: Any) => {
    const sample = (api.theme.current as Any)?.background
    const RGBA: Any = sample ? Object.getPrototypeOf(sample).constructor : undefined
    if (!RGBA) return

    // 1. Menu / popup backdrop. The only pure black partially transparent
    // colors in the whole TUI are the two scrims (ui/dialog.tsx:48 alpha 150
    // and routes/session/index.tsx:1351 alpha 70); fromInts(0,0,0,0) is
    // already fully transparent, so this only ever touches the scrims.
    const isBackdrop = (color: Color) =>
      color.r === 0 && color.g === 0 && color.b === 0 && color.a > 0 && color.a < 1

    for (const key of ["fromInts", "fromValues", "fromHex"]) {
      const original = RGBA[key]
      if (typeof original !== "function" || original.transparentBackdrop) continue
      const patched = function (...args: Any[]) {
        const color = original.apply(RGBA, args) as Color
        if (color && isBackdrop(color)) color.a = 0
        return color
      } as Patched
      patched.transparentBackdrop = true
      RGBA[key] = patched
    }

    // 2. Logo shadow backgrounds. The color is recomputed from the live theme
    // with the exact tint() formula, so this matches the logo cells and
    // nothing else (the logo is the only place a tint is used as bg=).
    const rgbKey = (color: Color) =>
      `${Math.round(color.r * 255)},${Math.round(color.g * 255)},${Math.round(color.b * 255)}`

    const shadowKey = (base: Color, overlay: Color) =>
      [
        Math.round((base.r + (overlay.r - base.r) * LOGO_SHADOW_MIX) * 255),
        Math.round((base.g + (overlay.g - base.g) * LOGO_SHADOW_MIX) * 255),
        Math.round((base.b + (overlay.b - base.b) * LOGO_SHADOW_MIX) * 255),
      ].join(",")

    const walk = (node: Any, visit: (node: Any) => void) => {
      if (!node) return
      try {
        visit(node)
      } catch {}
      let children: Any[] = []
      try {
        children = node.getChildren?.() ?? []
      } catch {}
      for (const child of children) walk(child, visit)
    }

    const clearLogoShadows = () => {
      const theme = api.theme.current as Any
      const background = theme.background
      // Only meaningful once the root background is transparent; with an
      // opaque background the shadow is the logo's own contrast.
      if (!background || background.a > 0.01) return
      const targets = new Set<string>()
      for (const fg of [theme.text, theme.textMuted]) {
        if (fg) targets.add(shadowKey(background, fg))
      }
      walk(api.renderer.root, (node) => {
        // Boxes carry the fill in backgroundColor, TextRenderable keeps the
        // default cell background in bg (which propagates to its chunk nodes).
        for (const prop of ["backgroundColor", "bg"]) {
          const color = node[prop] as Color | undefined
          if (!color || typeof color.r !== "number") continue
          if (color.a < 0.99 || !targets.has(rgbKey(color))) continue
          node[prop] = RGBA.fromValues(color.r, color.g, color.b, 0)
        }
      })
    }

    clearLogoShadows()
    const scan = setInterval(clearLogoShadows, 400)
    const reapply = () => setTimeout(clearLogoShadows, 0)
    api.renderer.on("palette", reapply)
    api.renderer.on("theme_mode", reapply)

    api.lifecycle.onDispose(() => clearInterval(scan))
  },
}

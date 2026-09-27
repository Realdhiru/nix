# Advisor Context & Architectural Memory

## Display & Shader Architecture Split

- **hyprsunset daemon** owns **Temperature + Gamma** (hardware CTM/gamma LUT).
- **Hyprland's single `decoration:screen_shader` slot** owns **Saturation + Paper Grain + CRT Curvature** together in one unified GLSL file, since Hyprland only supports one active `screen_shader` at a time.
- These two systems are fully independent — verify this separation before adding any new visual effect toggle, to avoid accidentally colliding with whichever mechanism already owns that property.

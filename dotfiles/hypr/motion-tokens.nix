# Single source of truth for the system motion language.
# dotfiles/hypr/motion.lua and dotfiles/hypr/scripts/quickshell/Motion.qml
# are generated from this attrset; the flake check regenerates both and
# byte-compares against the checked-in files.
{
  enter = { ms = 240; bezier = [ 0.16 1 0.3 1 ]; easing = "OutQuart"; };
  exit = { ms = 160; bezier = [ 0.4 0 1 1 ]; easing = "InQuad"; };
  move = { ms = 220; bezier = [ 0.22 1 0.36 1 ]; easing = "OutQuint"; };
  fade = { ms = 140; bezier = [ 0.25 0.1 0.25 1 ]; easing = "InOutQuad"; };

  # Press-hold progress fill (keep-or-delete: progress feedback).
  # Interaction affordance, not surface motion; single shared hold time.
  hold = { ms = 700; easing = "Linear"; };

  # State-carrying ambient loop (connected-ring breathing, glow pulse).
  # Slow InOutSine loop.
  ambient = { ms = 3200; easing = "InOutSine"; };

  # Rare large-surface morphs (power toggle, core state change). Ease-out.
  hero = { ms = 440; easing = "OutCubic"; };

  # Fast flow phase for hold/connecting waves and data-flow pulses.
  # Linear phase -> constant travel speed and exact repaint quantization.
  flow = { ms = 800; easing = "Linear"; };

  # Marquee (keep-or-delete: information reveal on text overflow).
  msPerPx = 30;
  pauseMs = 2500;
}

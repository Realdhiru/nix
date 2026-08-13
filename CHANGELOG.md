# CHANGELOG

## 2026-08-13 — Focus/popup/startup cleanup (commit 518f6ba)

### Fixed

1. **Rofi: Esc did not close the launcher**
   - Root cause: `steal-focus` defaults to false, so rofi (a layer surface) never
     received keyboard focus; Esc went to the previously focused app.
   - Fix: `steal-focus: true;` in `dotfiles/rofi/config.rasi`.

2. **Wallpaper picker could not be closed with Esc**
   - Root cause: `WallpaperPicker.qml` registered an unconditional `Escape`
     Shortcut (resetting only the Search filter). QML Shortcuts consume the key
     before the widget stack's `Keys.onEscapePressed` (`Main.qml`) can close the
     popup. Every other popup (clipboard, focustime, …) closes on Esc.
   - Fix: the shortcut is now active only in Search mode (`enabled:
     !window.isApplying && window.currentFilter === "Search"`). In Search mode:
     first Esc clears the filter, second Esc closes. Outside Search: Esc closes.

3. **Focus Time showed page titles as app names (e.g. "Opencode launcher setup")**
   - Root cause: `resolve_pwa_name` preferred the browser page title over the
     known host mapping, so a ChatGPT PWA tab titled "Opencode launcher setup"
     (a web page, not an app) became a row name.
   - Fix: known PWA hosts (`chat.openai.com`, `notion.so`, `claude.ai`,
     `gemini.google.com`, `monkeytype.com`, `youtube.com`) are now always
     resolved to their canonical names; page titles apply only to unknown
     hosts. `--heal` also retitles existing rows whose known-host title differs
     from the canonical name.

4. **Quickshell polled settings.json every 3 s forever**
   - Root cause: `Main.qml` spawned `bash -c cat settings.json` on a 3 s timer
     (a process spawn ~29×/min).
   - Fix: event-driven watcher `quickshell/watchers/settings_wait.sh`
     (inotifywait, 300 s failsafe, same pattern as the other watchers) feeding
     the existing `settingsReader` Process; read happens only on change.
   - Requires `inotify-tools` (added to `theme.nix` home.packages).

### Known issue — not changed (EasyEffects startup)

- `equalizer.sh --init` only waits for an EasyEffects process that nothing
  starts at login; the `easyeffects.service` has been dead since 2026-07-02.
- `equalizer.sh` writes presets to the legacy dir
  `~/.config/easyeffects/output`, while EasyEffects 8.2.7 uses
  `~/.local/share/easyeffects/output` and migrates/trashes on spawns.
- `pgrep -x easyeffects` cannot match the Nix-wrapped binary (`comm` =
  `.easyeffects-wr`), so readiness checks against the service are broken.
- Status: deliberately NOT modified; a redesign is required before any change.
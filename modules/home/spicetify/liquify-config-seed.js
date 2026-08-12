// Liquify V2 config seed — keeps the Liquify settings reproducible from ~/nix.
// Workflow: Liquify Settings -> modify -> copy Config JSON -> replace SETTINGS
// below -> nixos-rebuild switch -> restart Spotify.
// Semantics: applies SETTINGS only when this file changed since last apply,
// or when keys are missing (profile wiped). Runtime UI changes are preserved.
// Note: liquify-custom-color is deliberately NOT seeded — with accent-mode
// "dynamic" the theme derives it from the album art on every track change.
(function () {
  if (window.__liquifyConfigSeedInstalled) return;
  window.__liquifyConfigSeedInstalled = true;

  var SNAPSHOT_KEY = "liquifySeedSnapshot";

  var SETTINGS = {
    "liquify-accent-light-boost": "10",
    "liquify-accent-mode": "dynamic",
    "liquify-accent-sat-boost": "15",
    "liquify-accent-source": "background",
    "liquify-action-bar-box-mode": "show",
    "liquify-artist-bg-mode": "theme",
    "liquify-artist-scroll-blur": "15",
    "liquify-artist-scroll-brightness": "70",
    "liquify-backdrop-blur": "32",
    "liquify-bg-blur": "7",
    "liquify-bg-brightness": "50",
    "liquify-bg-custom-animated": "off",
    "liquify-bg-mode": "animated",
    "liquify-comfy-cover-enabled": "hide",
    "liquify-comfy-cover-height": "90",
    "liquify-comfy-cover-mb": "35",
    "liquify-comfy-cover-ml": "0",
    "liquify-comfy-cover-width": "90",
    "liquify-compact-player": "on",
    "liquify-connect-bar": "show",
    "liquify-floating-player": "on",
    "liquify-glass-blur": "2",
    "liquify-glass-enabled": "off",
    "liquify-glow-mode": "default",
    "liquify-home-layout": "on",
    "liquify-lyrics-font-size": "70",
    "liquify-lyrics-margin": "56",
    "liquify-lyrics-mode": "both",
    "liquify-main-radius": "20",
    "liquify-nav-radius": "20",
    "liquify-npv-cover-blur": "7",
    "liquify-npv-cover-mode": "off",
    "liquify-npv-cover-show-always": "no",
    "liquify-nsc-border-radius": "11",
    "liquify-nsc-cover-border-radius": "13",
    "liquify-nsc-cover-size": "25",
    "liquify-nsc-gap": "10",
    "liquify-nsc-gap-player": "4",
    "liquify-nsc-height": "38",
    "liquify-nsc-hpad": "5",
    "liquify-nsc-max-width": "256",
    "liquify-nsc-position": "left",
    "liquify-nsc-show": "hide",
    "liquify-nsc-vpad": "9",
    "liquify-onboarding-done": "1",
    "liquify-playbar-cover-border-radius": "12",
    "liquify-player-custom-height": "88",
    "liquify-player-custom-width": "56",
    "liquify-player-icons": "off",
    "liquify-player-radius": "30",
    "liquify-player-width": "custom",
    "liquify-playlist-header-mode": "show",
    "liquify-popup-bounce": "on",
    "liquify-progress-bar-compat": "off",
    "liquify-progress-bar-height": "20",
    "liquify-progress-bar-radius": "10",
    "liquify-right-radius": "20",
    "liquify-tc-height": "64",
    "liquify-tc-width": "135",
    "liquify-themed-lyrics": "off",
    "liquify-transparent-player": "off"
  };

  function seedJson() {
    return JSON.stringify(SETTINGS);
  }

  function applyAll() {
    var tries = 0;
    (function attempt() {
      if (typeof window.liquifyApplyAllSettings === "function") {
        window.liquifyApplyAllSettings();
        return;
      }
      if (++tries < 20) setTimeout(attempt, 250);
    })();
  }

  try {
    var applied = localStorage.getItem(SNAPSHOT_KEY);
    var seedChanged = applied !== seedJson();
    var wrote = false;

    if (seedChanged) {
      for (var k in SETTINGS) localStorage.setItem(k, String(SETTINGS[k]));
      localStorage.setItem(SNAPSHOT_KEY, seedJson());
      wrote = true;
      console.warn("[liquify-config-seed] repository config applied");
    } else {
      var missing = [];
      for (var k2 in SETTINGS) if (localStorage.getItem(k2) === null) missing.push(k2);
      if (missing.length) {
        for (var m = 0; m < missing.length; m++) localStorage.setItem(missing[m], String(SETTINGS[missing[m]]));
        wrote = true;
        console.warn("[liquify-config-seed] re-seeded missing keys: " + missing.join(", "));
      } else {
        var drifted = [];
        for (var d in SETTINGS)
          if (String(localStorage.getItem(d)) !== String(SETTINGS[d])) drifted.push(d);
        if (drifted.length)
          console.warn(
            "[liquify-config-seed] runtime settings differ from repo seed (" +
              drifted.length +
              " keys). To persist them: Liquify Settings -> Config -> copy JSON into this file and rebuild."
          );
      }
    }
    if (wrote) applyAll();
  } catch (e) {
    console.error("[liquify-config-seed]", e);
  }
})();

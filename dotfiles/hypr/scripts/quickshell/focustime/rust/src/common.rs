use rusqlite::Connection;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::{LazyLock, Mutex};

pub static DESKTOP_CACHE: LazyLock<Mutex<DesktopCache>> = LazyLock::new(|| {
    let mut cache = DesktopCache::new();
    cache.build();
    Mutex::new(cache)
});

pub fn get_db_path() -> PathBuf {
    if let Ok(dir) = std::env::var("QS_STATE_FOCUSTIME") {
        PathBuf::from(dir).join("focustime.db")
    } else {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        let state_home = std::env::var("XDG_STATE_HOME").unwrap_or_else(|_| format!("{}/.local/state", home));
        PathBuf::from(state_home).join("desktop/focustime/focustime.db")
    }
}

pub fn init_db(conn: &Connection) -> rusqlite::Result<()> {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS focus_log (
            log_date TEXT,
            app_class TEXT,
            seconds INTEGER,
            app_title TEXT,
            PRIMARY KEY (log_date, app_class)
        )",
        [],
    )?;
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_log_date ON focus_log(log_date)",
        [],
    )?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS focus_hourly (
            log_date TEXT,
            hour INTEGER,
            app_class TEXT,
            seconds INTEGER,
            PRIMARY KEY (log_date, hour, app_class)
        )",
        [],
    )?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS focus_intervals (
            log_date TEXT,
            interval_idx INTEGER,
            app_class TEXT,
            seconds INTEGER,
            PRIMARY KEY (log_date, interval_idx, app_class)
        )",
        [],
    )?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS focus_minutes (
            log_date TEXT,
            minute_idx INTEGER,
            app_class TEXT,
            seconds INTEGER,
            PRIMARY KEY (log_date, minute_idx, app_class)
        )",
        [],
    )?;
    Ok(())
}

pub struct DesktopCache {
    pub names: HashMap<String, String>,
    pub icons: HashMap<String, String>,
    pub theme_icons: HashMap<String, String>,
}

impl DesktopCache {
    pub fn new() -> Self {
        Self {
            names: HashMap::new(),
            icons: HashMap::new(),
            theme_icons: HashMap::new(),
        }
    }

    pub fn build(&mut self) {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        let xdg_data_home = std::env::var("XDG_DATA_HOME").unwrap_or_else(|_| format!("{}/.local/share", home));
        let xdg_data_dirs = std::env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".to_string());

        let mut app_dirs = vec![PathBuf::from(&xdg_data_home).join("applications")];
        for d in xdg_data_dirs.split(':') {
            if !d.trim().is_empty() {
                app_dirs.push(PathBuf::from(d.trim()).join("applications"));
            }
        }
        app_dirs.push(PathBuf::from("/var/lib/flatpak/exports/share/applications"));
        app_dirs.push(PathBuf::from("/var/lib/snapd/desktop/applications"));

        for dir in app_dirs {
            if !dir.is_dir() {
                continue;
            }
            if let Ok(entries) = fs::read_dir(dir) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("desktop") {
                        let stem = path.file_stem().and_then(|s| s.to_str()).unwrap_or("").to_lowercase();
                        if let Ok(content) = fs::read_to_string(&path) {
                            let mut name: Option<String> = None;
                            let mut icon: Option<String> = None;
                            let mut wmclass: Option<String> = None;

                            for line in content.lines() {
                                let line = line.trim();
                                if line.starts_with("Name=") && name.is_none() {
                                    name = Some(line[5..].trim().to_string());
                                } else if line.starts_with("Icon=") && icon.is_none() {
                                    icon = Some(line[5..].trim().to_string());
                                } else if line.starts_with("StartupWMClass=") && wmclass.is_none() {
                                    wmclass = Some(line[15..].trim().to_lowercase());
                                }
                            }

                            if let Some(n) = name {
                                let ic = icon.unwrap_or_default();
                                self.names.insert(stem.clone(), n.clone());
                                self.icons.insert(stem, ic.clone());
                                if let Some(wmc) = wmclass {
                                    self.names.insert(wmc.clone(), n);
                                    self.icons.insert(wmc, ic);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Build theme icons
        let mut icon_dirs = vec![
            PathBuf::from(&xdg_data_home).join("icons"),
            PathBuf::from(&home).join(".icons"),
        ];
        for d in xdg_data_dirs.split(':') {
            if !d.trim().is_empty() {
                icon_dirs.push(PathBuf::from(d.trim()).join("icons"));
            }
        }

        for base in icon_dirs {
            if !base.is_dir() {
                continue;
            }
            if let Ok(themes) = fs::read_dir(base) {
                for theme in themes.flatten() {
                    let theme_dir = theme.path();
                    if !theme_dir.is_dir() {
                        continue;
                    }
                    for subdir in ["apps", "scalable/apps"] {
                        let apps_dir = theme_dir.join(subdir);
                        if apps_dir.is_dir() {
                            if let Ok(files) = fs::read_dir(apps_dir) {
                                for f in files.flatten() {
                                    let p = f.path();
                                    if let Some(ext) = p.extension().and_then(|e| e.to_str()) {
                                        let ext_lower = ext.to_lowercase();
                                        if ext_lower == "svg" || ext_lower == "png" || ext_lower == "xpm" {
                                            if let Some(stem) = p.file_stem().and_then(|s| s.to_str()) {
                                                self.theme_icons.insert(stem.to_lowercase(), stem.to_string());
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    pub fn get_app_icon(&self, app_class: &str) -> String {
        if app_class.is_empty() || is_system_class(app_class) {
            return String::new();
        }

        let lower = app_class.to_lowercase();
        let base = lower
            .trim_end_matches("-updater")
            .trim_end_matches("_updater")
            .trim_end_matches(" updater")
            .trim_end_matches(".exe");

        if let Some(ic) = self.icons.get(&lower) {
            if !ic.is_empty() {
                return ic.clone();
            }
        }
        if let Some(ic) = self.icons.get(base) {
            if !ic.is_empty() {
                return ic.clone();
            }
        }
        if let Some(ic) = self.theme_icons.get(&lower) {
            return ic.clone();
        }
        if let Some(ic) = self.theme_icons.get(app_class) {
            return ic.clone();
        }

        String::new()
    }

    pub fn resolve_app_name(&mut self, app_class: &str, raw_title: &str) -> String {
        if app_class.is_empty() || is_system_class(app_class) {
            return if app_class.is_empty() { "Unknown".to_string() } else { app_class.to_string() };
        }

        let lower = app_class.to_lowercase();
        let base = lower
            .trim_end_matches("-updater")
            .trim_end_matches("_updater")
            .trim_end_matches(" updater")
            .trim_end_matches(".exe");

        if let Some(name) = self.names.get(&lower) {
            return name.clone();
        }
        if let Some(name) = self.names.get(base) {
            return name.clone();
        }

        if let Some(pwa) = resolve_pwa_name(&lower, raw_title) {
            self.names.insert(lower, pwa.clone());
            return pwa;
        }

        let cleaned = clean_window_title(raw_title);
        let name = if cleaned.is_empty() || is_placeholder_title(&cleaned) || looks_like_host(&cleaned) || cleaned.len() > 25 {
            prettify_class(app_class)
        } else {
            cleaned
        };

        self.names.insert(lower, name.clone());
        name
    }
}

pub fn is_system_class(cls: &str) -> bool {
    matches!(cls, "Desktop" | "Locked" | "Quickshell" | "Unknown") || cls.to_lowercase().starts_with("xdg-desktop-portal")
}

pub fn is_placeholder_title(t: &str) -> bool {
    let lower = t.to_lowercase();
    matches!(lower.as_str(), "new tab" | "brave" | "chromium" | "google chrome" | "chrome")
}

pub fn looks_like_host(text: &str) -> bool {
    if text.contains('.') {
        let parts: Vec<&str> = text.split('.').collect();
        if parts.len() >= 2 && parts.last().map(|s| s.len() >= 2).unwrap_or(false) {
            return true;
        }
    }
    false
}

pub fn pwa_host_from_class(cls: &str) -> Option<&str> {
    for prefix in ["brave-", "chromium-", "google-chrome-"] {
        if let Some(rest) = cls.strip_prefix(prefix) {
            if let Some(idx) = rest.find("__") {
                return Some(&rest[..idx]);
            }
        }
    }
    None
}

pub fn pretty_host(host: &str) -> String {
    let h = host.strip_prefix("www.").unwrap_or(host);
    let parts: Vec<&str> = h.split('.').collect();
    if parts.len() >= 2 {
        capitalize(parts[parts.len() - 2])
    } else {
        capitalize(h)
    }
}

pub fn capitalize(s: &str) -> String {
    let mut c = s.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
    }
}

pub fn prettify_class(cls: &str) -> String {
    let lower = cls.to_lowercase();
    if lower == "chatgpt" {
        return "ChatGPT".to_string();
    }
    let parts: Vec<String> = cls
        .split(|c: char| !c.is_alphanumeric())
        .filter(|p| !p.is_empty())
        .map(capitalize)
        .collect();
    if parts.is_empty() {
        capitalize(cls)
    } else {
        parts.join(" ")
    }
}

pub fn resolve_pwa_name(app_class: &str, raw_title: &str) -> Option<String> {
    let host = pwa_host_from_class(app_class)?;
    let canonical = match host {
        "chat.openai.com" => Some("ChatGPT"),
        "www.notion.so" => Some("Notion"),
        "claude.ai" => Some("Claude"),
        "gemini.google.com" => Some("Gemini"),
        "monkeytype.com" => Some("Monkeytype"),
        "youtube.com" => Some("YouTube"),
        "web.whatsapp.com" => Some("Whatsapp"),
        _ => None,
    };
    if let Some(c) = canonical {
        return Some(c.to_string());
    }

    let cleaned = clean_window_title(raw_title);
    if !cleaned.is_empty() && cleaned.len() <= 25 && !looks_like_host(&cleaned) && cleaned.to_lowercase() != host.to_lowercase() && !is_placeholder_title(&cleaned) {
        return Some(cleaned);
    }

    Some(pretty_host(host))
}

pub fn clean_window_title(raw: &str) -> String {
    let mut s = raw.trim();
    // Strip leading count like (1) or [2]
    if s.starts_with('(') || s.starts_with('[') {
        if let Some(idx) = s.find(|c| c == ')' || c == ']') {
            s = s[idx + 1..].trim();
        }
    }
    // Strip trailing browser suffix
    for suffix in [" - Brave", " - Chromium", " - Google Chrome", " — Brave", " | Brave"] {
        if let Some(stripped) = s.strip_suffix(suffix) {
            s = stripped.trim();
        }
    }
    // Split by " - " or " — "
    if let Some(idx) = s.rfind(" - ") {
        s = s[idx + 3..].trim();
    } else if let Some(idx) = s.rfind(" — ") {
        s = s[idx + 3..].trim();
    }
    s.to_string()
}

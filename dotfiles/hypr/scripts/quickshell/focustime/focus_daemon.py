#!/usr/bin/env python3
import argparse
import subprocess
import sqlite3
import time
import os
import socket
import json
import threading
import calendar
import re
import signal
import sys
import shutil
import glob
from datetime import date, datetime, timedelta
from collections import defaultdict

current_app_class = "Desktop"
current_app_title = "Desktop"

# True once the Hyprland event socket is connected and stream is open.
# fast_tick() is skipped while False so no time is attributed to
# "Unknown"/"Desktop" before Hyprland is reachable (boot race) or while
# it is restarting.
hyprland_connected = False

# Guards the (class, title) pair above. Written by listen_hyprland_ipc()
# (background thread) and read by main()'s tick loop (main thread). Without
# this, a read can land between the two assignments and pair a new class
# with the previous title for one tick.
_state_lock = threading.Lock()

# Use standardized dynamic paths securely
DB_DIR = os.environ.get("QS_STATE_FOCUSTIME", os.path.expanduser("~/.local/state/quickshell/focustime"))
os.makedirs(DB_DIR, exist_ok=True)
DB_PATH = os.path.join(DB_DIR, "focustime.db")

# Database Migration Fallback
OLD_DB_DIR = os.path.expanduser("~/.local/share/focustime")
OLD_DB_BASE = os.path.join(OLD_DB_DIR, "focustime.db")

if not os.path.exists(DB_PATH) and os.path.exists(OLD_DB_BASE):
    try:
        # Move the main db and any shm/wal/journal files safely
        for old_file in glob.glob(OLD_DB_BASE + "*"):
            shutil.move(old_file, DB_DIR)
    except Exception:
        pass

RUN_DIR = os.environ.get("QS_RUN_FOCUSTIME", "/tmp/quickshell/focustime")
os.makedirs(RUN_DIR, exist_ok=True)
STATE_FILE = os.path.join(RUN_DIR, "focustime_state.json")

DESKTOP_CACHE_NAME = {}
DESKTOP_CACHE_ICON = {}
DESKTOP_CACHE_SOURCE = {}
CACHE_BUILT = False

# Lowercased icon file stem -> canonical name, built once from the XDG
# icon theme directories (freedesktop icon theme spec).
ICON_THEME_INDEX = {}
ICON_THEME_BUILT = False

SYSTEM_STATES = {"Desktop", "Locked", "Quickshell", "Unknown"}

# Wayland infrastructure windows (xdg-desktop-portal permission/chooser
# dialogs) are focus-grabbing helpers, not user applications.
PORTAL_PREFIX = "xdg-desktop-portal"

# Chromium-family placeholder window titles (no-content pages, bare browser
# names) that carry no app identity and must not be shown as app names.
PLACEHOLDER_TITLES = {"new tab", "brave", "chromium", "google chrome", "chrome"}

def is_portal_class(app_class):
    return bool(app_class) and app_class.lower().startswith(PORTAL_PREFIX)

def is_system_class(app_class):
    return bool(app_class) and (app_class in SYSTEM_STATES or is_portal_class(app_class))

# Chromium-family installed web apps report the WM_CLASS format
# <browser>-<host>__<appid>-Default (the plain browser window itself, e.g.
# "brave-browser", has no "__" part and is not a PWA, so it is not matched).
CHROMIUM_PWA_RE = re.compile(r'^(?:brave|chromium|google-chrome)-(.+?)__')

# Human-readable display names for the installed web-app set. Installed PWAs
# expose no standard desktop metadata here (no .desktop entries, no web-app
# registry in Brave's Preferences), so the host parsed from the WM_CLASS is
# mapped; unknown hosts fall back to a generic prettified domain.
PWA_HOST_NAMES = {
    "chat.openai.com": "ChatGPT",
    "www.notion.so": "Notion",
    "claude.ai": "Claude",
    "gemini.google.com": "Gemini",
    "monkeytype.com": "Monkeytype",
    "youtube.com": "YouTube",
}

# Non-PWA classes whose WM_CLASS prettifies ambiguously (e.g. the ChatGPT
# desktop client reports WM_CLASS "chatgpt" with placeholder titles).
KNOWN_CLASS_NAMES = {
    "chatgpt": "ChatGPT",
}

# Browser window-title suffixes, e.g. "ChatGPT - Brave". Stripped before
# splitting so the page name is taken instead of the browser name.
BROWSER_TITLE_SUFFIX_RE = re.compile(
    r'\s*[-—|]\s*(?:Brave|Chromium|Google Chrome|Chrome)\s*$', re.IGNORECASE)

def get_xdg_search_dirs():
    search_dirs = []
    xdg_data_home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    search_dirs.append(os.path.join(xdg_data_home, "applications"))
    
    xdg_data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    for d in xdg_data_dirs.split(":"):
        if d.strip():
            search_dirs.append(os.path.join(d, "applications"))

    fallback_dirs = [
        "/var/lib/flatpak/exports/share/applications",
        "/var/lib/snapd/desktop/applications"
    ]
    for d in fallback_dirs:
        if d not in search_dirs:
            search_dirs.append(d)
    return search_dirs

def build_desktop_cache():
    global CACHE_BUILT
    if CACHE_BUILT: return
    
    for directory in get_xdg_search_dirs():
        if not os.path.exists(directory): continue
        try:
            for f in os.listdir(directory):
                if f.endswith(".desktop"):
                    path = os.path.join(directory, f)
                    try:
                        name, icon, wmclass = None, "", None
                        with open(path, 'r', encoding='utf-8') as file:
                            for line in file:
                                line = line.strip()
                                if line.startswith("Name=") and not name:
                                    name = line.split("=", 1)[1].strip()
                                elif line.startswith("Icon=") and not icon:
                                    icon = line.split("=", 1)[1].strip()
                                elif line.startswith("StartupWMClass="):
                                    wmclass = line.split("=", 1)[1].strip().lower()
                        
                        if name:
                            base = f[:-8].lower()
                            DESKTOP_CACHE_NAME[base] = name
                            DESKTOP_CACHE_ICON[base] = icon
                            DESKTOP_CACHE_SOURCE[base] = "desktop"
                            if wmclass:
                                DESKTOP_CACHE_NAME[wmclass] = name
                                DESKTOP_CACHE_ICON[wmclass] = icon
                                DESKTOP_CACHE_SOURCE[wmclass] = "startup_wmclass"
                    except Exception:
                        pass
        except Exception:
            pass
    CACHE_BUILT = True

def pwa_host_from_class(app_class):
    """Return the site host for a Chromium-family installed web app, or None."""
    m = CHROMIUM_PWA_RE.match(app_class)
    return m.group(1).strip() if m else None

def looks_like_host(text):
    """True when a title is a URL-ish fallback (e.g. 'youtube.com_/' or
    'claude.ai_/new' — Brave's default app-window title when no manifest
    name is available)."""
    return bool(re.match(r'^[\w.-]+\.[a-z]{2,}(?:[_/][\w./_%-]*)?$', text, re.IGNORECASE))

def pretty_host(host):
    """Generic fallback: 'www.notion.so' -> 'Notion', 'mail.google.com' -> 'Google'."""
    h = host[4:] if host.startswith("www.") else host
    labels = h.split(".")
    if len(labels) >= 2:
        h = labels[-2]
    return h.capitalize()

def prettify_class(app_class):
    """Identity fallback when no usable title exists: 'chatgpt' -> 'ChatGPT',
    'com.dec05eba.gpu_screen_recorder' -> 'Gpu Screen Recorder'."""
    if app_class.lower() in KNOWN_CLASS_NAMES:
        return KNOWN_CLASS_NAMES[app_class.lower()]
    parts = [p for p in re.split(r'[^a-zA-Z0-9]+', app_class) if p]
    if not parts:
        return app_class.capitalize()
    return ' '.join(p.capitalize() for p in parts)

def resolve_pwa_name(app_class, raw_title):
    """Resolve a Chromium-family installed web app to a clean display name.

    Preference order: cleaned window title (page name) -> host map ->
    generic domain fallback. Returns None for non-PWA classes.
    """
    host = pwa_host_from_class(app_class)
    if not host:
        return None

    clean = re.sub(r'^\(\d+\)\s*|^\[\d+\]\s*', '', raw_title or "")
    clean = re.sub(r'\s*\(\d+\)$', '', clean)
    clean = BROWSER_TITLE_SUFFIX_RE.sub('', clean)
    parts = re.split(r'\s+[-—|]\s+', clean)
    name = parts[-1].strip() if len(parts) > 1 else clean.strip()

    if (name and len(name) <= 25 and not looks_like_host(name)
            and name.lower() != host and name.lower() not in PLACEHOLDER_TITLES):
        return name

    return PWA_HOST_NAMES.get(host) or pretty_host(host)

def resolve_app_name(app_class, raw_title):
    if not app_class or app_class in SYSTEM_STATES:
        return app_class if app_class else "Unknown"
        
    build_desktop_cache()
    app_class_lower = app_class.lower()
    base_class = re.sub(r'[-_ ]?updater$', '', app_class_lower)
    base_class = base_class.replace('.exe', '')

    if app_class_lower in DESKTOP_CACHE_NAME: return DESKTOP_CACHE_NAME[app_class_lower]
    if base_class in DESKTOP_CACHE_NAME: return DESKTOP_CACHE_NAME[base_class]

    pwa_name = resolve_pwa_name(app_class_lower, raw_title)
    if pwa_name is not None:
        DESKTOP_CACHE_NAME[app_class_lower] = pwa_name
        return pwa_name

    clean_title = re.sub(r'^\(\d+\)\s*|^\[\d+\]\s*', '', raw_title)
    clean_title = re.sub(r'\s*\(\d+\)$', '', clean_title)
    clean_title = BROWSER_TITLE_SUFFIX_RE.sub('', clean_title)
    parts = re.split(r'\s+[-—|]\s+', clean_title)
    name = parts[-1].strip() if len(parts) > 1 else clean_title.strip()

    if not name or name.lower() in PLACEHOLDER_TITLES or looks_like_host(name) or len(name) > 25:
        name = prettify_class(app_class)

    DESKTOP_CACHE_NAME[app_class_lower] = name
    return name

def get_xdg_icon_theme_dirs():
    """All XDG icon theme base directories, per the freedesktop spec."""
    dirs = []
    xdg_data_home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    dirs.append(os.path.join(xdg_data_home, "icons"))
    dirs.append(os.path.expanduser("~/.icons"))

    xdg_data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    for d in xdg_data_dirs.split(":"):
        if d.strip():
            dirs.append(os.path.join(d, "icons"))
    return dirs

def build_icon_theme_index():
    """Index every themed icon file stem found under the XDG icon search
    paths (e.g. hicolor/*/apps/<name>.svg|png, scalable/apps). Lookup of an
    arbitrary WM_CLASS name becomes an O(1) membership test, and the index is
    per-theme-agnostic: icons from every installed theme count."""
    global ICON_THEME_BUILT
    if ICON_THEME_BUILT:
        return
    for base in get_xdg_icon_theme_dirs():
        if not os.path.isdir(base):
            continue
        try:
            for theme in os.listdir(base):
                theme_dir = os.path.join(base, theme)
                if not os.path.isdir(theme_dir):
                    continue
                for subdir in ("apps", "scalable/apps"):
                    apps_dir = os.path.join(theme_dir, subdir)
                    if not os.path.isdir(apps_dir):
                        continue
                    for f in os.listdir(apps_dir):
                        stem, ext = os.path.splitext(f)
                        if ext.lower() not in (".svg", ".png", ".xpm"):
                            continue
                        key = stem.lower()
                        if key not in ICON_THEME_INDEX:
                            ICON_THEME_INDEX[key] = stem
        except Exception:
            pass
    ICON_THEME_BUILT = True

def theme_icon_lookup(name):
    """Freedesktop icon theme lookup by icon name. Tries the given name and
    a lowercase variant. Returns the canonical theme icon name, or ''."""
    if not name:
        return ""
    build_icon_theme_index()
    for variant in (name, name.lower()):
        if variant in ICON_THEME_INDEX:
            return ICON_THEME_INDEX[variant]
    return ""

def get_app_icon(app_class):
    if not app_class or is_system_class(app_class):
        return ""

    build_desktop_cache()
    app_class_lower = app_class.lower()
    base_class = re.sub(r'[-_ ]?updater$', '', app_class_lower)
    base_class = base_class.replace('.exe', '')

    if app_class_lower in DESKTOP_CACHE_ICON: return DESKTOP_CACHE_ICON[app_class_lower]
    if base_class in DESKTOP_CACHE_ICON: return DESKTOP_CACHE_ICON[base_class]

    # Fall back to a generic XDG icon-theme lookup for the window's own
    # WM_CLASS / app_id (which frequently doubles as an icon name, e.g. a
    # GTK app without a desktop entry but with a theme icon).
    return theme_icon_lookup(app_class)

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS focus_log (log_date TEXT, app_class TEXT, seconds INTEGER, app_title TEXT, PRIMARY KEY (log_date, app_class))''')
    c.execute('CREATE INDEX IF NOT EXISTS idx_log_date ON focus_log(log_date)')
    c.execute('''CREATE TABLE IF NOT EXISTS focus_hourly (log_date TEXT, hour INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, hour, app_class))''')
    c.execute('''CREATE TABLE IF NOT EXISTS focus_intervals (log_date TEXT, interval_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, interval_idx, app_class))''')
    c.execute('''CREATE TABLE IF NOT EXISTS focus_minutes (log_date TEXT, minute_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, minute_idx, app_class))''')
    
    c.execute("PRAGMA table_info(focus_log)")
    if 'app_title' not in [row[1] for row in c.fetchall()]:
        c.execute('ALTER TABLE focus_log ADD COLUMN app_title TEXT')
        
    conn.commit()
    return conn

def get_active_window_hyprctl():
    try:
        output = subprocess.check_output(['hyprctl', 'activewindow', '-j'], text=True)
        if output.strip() == "{}": return "Desktop", "Desktop"
        data = json.loads(output)
        
        # Prefer the current class/title over the frozen initial* values:
        # initialTitle is captured at window creation and never updates, so a
        # Chromium-family window opened on "New Tab" would report "New Tab" for
        # its entire lifetime regardless of the page it actually shows.
        app_cls = data.get('class') or data.get('initialClass') or ''
        raw_title = data.get('title') or data.get('initialTitle') or ''

        if "quickshell" in app_cls.lower() or "qs-master" in raw_title.lower() or "qs-master" in app_cls.lower():
            return "Quickshell", "Quickshell"

        if is_system_class(app_cls):
            return "Desktop", "Desktop"

        app_cls = app_cls if app_cls else "Unknown"
        raw_title = raw_title if raw_title else app_cls
        clean_name = resolve_app_name(app_cls, raw_title)
        return app_cls, clean_name
    except Exception:
        return "Unknown", "Unknown"

def is_locked():
    try:
        subprocess.check_output(['pgrep', '-x', 'hyprlock'])
        return True
    except subprocess.CalledProcessError:
        return False

def resolve_hypr_signature():
    """Current Hyprland instance signature, or None.

    HYPRLAND_INSTANCE_SIGNATURE is normally present in environments spawned
    by Hyprland itself (exec-once etc.), but a systemd user service has no
    such env. The signature also changes every Hyprland restart, so it must
    be re-resolved rather than trusted from the environment. Discovery order:
    1. env var (fast path, session-launched contexts)
    2. `hyprctl instances -j` (authoritative, works without the env var)
    3. first *.sock2 directory under $XDG_RUNTIME_DIR/hypr/
    """
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "")
    if runtime_dir and sig and os.path.isdir(os.path.join(runtime_dir, "hypr", sig)):
        return sig

    try:
        out = subprocess.check_output(['hyprctl', 'instances', '-j'], text=True)
        data = json.loads(out)
        if isinstance(data, list):
            for entry in data:
                if isinstance(entry, dict) and entry.get("instance"):
                    os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = entry["instance"]
                    return entry["instance"]
        elif isinstance(data, dict) and data.get("instance"):
            os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = data["instance"]
            return data["instance"]
    except Exception:
        pass

    glob_base = runtime_dir if runtime_dir else "/tmp"
    try:
        hypr_base = os.path.join(glob_base, "hypr")
        if os.path.isdir(hypr_base):
            for name in sorted(os.listdir(hypr_base)):
                if os.path.isdir(os.path.join(hypr_base, name)):
                    os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = name
                    return name
    except Exception:
        pass

    return None

def listen_hyprland_ipc():
    global current_app_class, current_app_title, hyprland_connected
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")

    while True:
        sig = resolve_hypr_signature()
        sock_path = None
        if sig:
            candidate = os.path.join(runtime_dir, "hypr", sig, ".socket2.sock")
            if os.path.exists(candidate):
                sock_path = candidate
        if not sock_path:
            with _state_lock:
                hyprland_connected = False
            time.sleep(2)
            continue

        try:
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client.connect(sock_path)
            with _state_lock:
                hyprland_connected = True
            buffer = ""
            while True:
                data = client.recv(4096).decode('utf-8')
                if not data: break
                buffer += data
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if line.startswith('activewindow>>'):
                        cls, clean_title = get_active_window_hyprctl()
                        with _state_lock:
                            if is_locked() or cls == "hyprlock":
                                current_app_class, current_app_title = "Locked", "Locked"
                            else:
                                current_app_class, current_app_title = cls, clean_title
            client.close()
        except Exception:
            pass
        with _state_lock:
            hyprland_connected = False
        time.sleep(2) 


class DaemonTracker:
    def __init__(self):
        self.conn = init_db()
        self.buffer = []
        self.cached_json = None
        self.last_sync = 0
        self.last_date = date.today()
        
    def full_sync(self, target_date, app_title):
        c = self.conn.cursor()
        
        yesterday = target_date - timedelta(days=1)
        c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (yesterday.isoformat(),))
        yesterday_seconds = c.fetchone()[0] or 0

        monday = target_date - timedelta(days=target_date.weekday())
        sunday = monday + timedelta(days=6)
        week_range_str = f"{monday.strftime('%b')} {monday.day} - {sunday.strftime('%b')} {sunday.day}"

        c.execute('''SELECT COUNT(DISTINCT log_date), SUM(seconds) FROM focus_log 
                     WHERE log_date >= ? AND log_date <= ? AND seconds > 0''', (monday.isoformat(), sunday.isoformat()))
        row = c.fetchone()
        days_count = row[0] or 0
        total_week = row[1] or 0
        average_seconds = total_week // days_count if days_count > 0 else 0
        
        c.execute('SELECT SUM(seconds) FROM focus_log WHERE log_date = ?', (target_date.isoformat(),))
        total_seconds = c.fetchone()[0] or 0

        c.execute('''SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs 
                     FROM focus_log WHERE log_date = ? GROUP BY app_class ORDER BY secs DESC''', (target_date.isoformat(),))
        all_apps = []
        for row in c.fetchall():
            app_class, app_title, secs = row
            if secs == 0: continue
            all_apps.append({
                "class": app_class, "name": app_title, "icon": get_app_icon(app_class),
                "seconds": secs, "percent": round((secs / total_seconds) * 100, 1) if total_seconds > 0 else 0
            })

        c.execute('''SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log 
                     WHERE log_date >= ? AND log_date <= ? GROUP BY app_class ORDER BY secs DESC LIMIT 50''', 
                  (monday.isoformat(), sunday.isoformat()))
        week_apps_rows = c.fetchall()
        week_apps_total = sum([r[2] for r in week_apps_rows])
        week_apps = []
        for r in week_apps_rows:
            cls, title, secs = r
            if secs == 0: continue
            week_apps.append({
                "class": cls, "name": title, "icon": get_app_icon(cls),
                "seconds": secs, "percent": round((secs / week_apps_total) * 100, 1) if week_apps_total > 0 else 0
            })

        c.execute('SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? GROUP BY log_date', 
                 (monday.isoformat(), sunday.isoformat()))
        week_map = {r[0]: r[1] for r in c.fetchall()}
        days_str = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        week_data = []
        for i in range(7):
            d_str = (monday + timedelta(days=i)).isoformat()
            week_data.append({"date": d_str, "day": days_str[i], "total": week_map.get(d_str, 0), "is_target": d_str == target_date.isoformat()})

        first_day = target_date.replace(day=1)
        _, num_days = calendar.monthrange(target_date.year, target_date.month)
        last_day = target_date.replace(day=num_days)
        c.execute('SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? GROUP BY log_date', 
                 (first_day.isoformat(), last_day.isoformat()))
        month_map = {r[0]: r[1] for r in c.fetchall()}
        
        month_data = [{"date": "", "total": -1, "is_target": False} for _ in range(first_day.weekday())]
        for i in range(1, num_days + 1):
            d_str = target_date.replace(day=i).isoformat()
            month_data.append({"date": d_str, "total": month_map.get(d_str, 0), "is_target": d_str == target_date.isoformat()})

        hourly_data = [0] * 48
        try:
            # NOTE: intentionally sourced from focus_intervals ONLY.
            # focus_hourly logs the exact same seconds at coarser (1hr)
            # granularity, not additional time — a previous version of
            # this code summed both into hourly_data, which double-counted
            # every second of activity (and unevenly: the focus_hourly
            # total landed entirely on one half of its hour, skewing the
            # by-time-of-day chart). focus_intervals (15-min buckets,
            # idx // 2 -> the matching 30-min slot) matches the live-tick
            # path's own granularity (see fast_tick's `idx = hr*2 + ...`
            # above) and is sufficient on its own.
            c.execute('SELECT interval_idx, SUM(seconds) FROM focus_intervals WHERE log_date = ? GROUP BY interval_idx', (target_date.isoformat(),))
            for idx, secs in c.fetchall():
                if 0 <= idx < 96: hourly_data[idx // 2] += secs
        except sqlite3.OperationalError:
            pass 

        week_heatmap = [[0]*24 for _ in range(7)]
        try:
            c.execute('''SELECT log_date, hour, SUM(seconds) FROM focus_hourly WHERE log_date >= ? AND log_date <= ? GROUP BY log_date, hour''', 
                      (monday.isoformat(), sunday.isoformat()))
            for ldate, hr, secs in c.fetchall():
                day_idx = date.fromisoformat(ldate).weekday()
                if 0 <= hr <= 23: week_heatmap[day_idx][hr] += secs
        except sqlite3.OperationalError:
            pass

        minute_data = [0] * 1440
        try:
            c.execute('''SELECT minute_idx, SUM(seconds) FROM focus_minutes WHERE log_date >= ? AND log_date <= ? GROUP BY minute_idx''', 
                      (monday.isoformat(), sunday.isoformat()))
            for idx, secs in c.fetchall():
                if 0 <= idx < 1440: minute_data[idx] += secs
        except sqlite3.OperationalError:
            pass

        peak_str = "N/A"
        max_sum = 0
        best_window = None
        for i in range(1440 - 60):
            w_sum = sum(minute_data[i:i+60])
            if w_sum > max_sum and w_sum > 0:
                max_sum = w_sum
                best_window = (i, i+60)

        if best_window:
            start_idx, end_idx = best_window
            while start_idx < end_idx and minute_data[start_idx] == 0: start_idx += 1
            actual_end = end_idx - 1
            while actual_end > start_idx and minute_data[actual_end] == 0: actual_end -= 1
            s_h, s_m = divmod(start_idx, 60)
            e_h, e_m = divmod(actual_end, 60)
            peak_str = f"{s_h:02d}:{s_m:02d} - {e_h:02d}:{e_m:02d}"

        self.cached_json = {
            "selected_date": target_date.isoformat(), "total": total_seconds, "average": average_seconds,
            "week_range": week_range_str, "yesterday": yesterday_seconds, "current": app_title,
            "apps": all_apps, "week_apps": week_apps, "week": week_data, "month": month_data,
            "hourly": hourly_data, "week_heatmap": week_heatmap, "peak_usage_str": peak_str
        }
        self.last_sync = time.time()
        self.last_date = target_date
        
    def fast_tick(self, app_class, app_title, write_to_disk=True):
        now = datetime.now()
        target_date = now.date()
        
        self.buffer.append((target_date.isoformat(), app_class, app_title, now))
        
        if self.cached_json is None or target_date != self.last_date or (time.time() - self.last_sync > 60):
            self.flush()
            self.full_sync(target_date, app_title)
        else:
            d = self.cached_json
            d["total"] += 1
            d["current"] = app_title
            
            found = False
            for app in d["apps"]:
                if app["class"] == app_class:
                    app["seconds"] += 1
                    found = True
                    break
            if not found:
                d["apps"].append({
                    "class": app_class, "name": app_title, 
                    "icon": get_app_icon(app_class), "seconds": 1, "percent": 0
                })
                
            for app in d["apps"]:
                app["percent"] = round((app["seconds"] / d["total"]) * 100, 1) if d["total"] > 0 else 0
            d["apps"].sort(key=lambda x: x["seconds"], reverse=True)
            
            for w in d["week"]:
                if w["is_target"]: w["total"] += 1
            for m in d["month"]:
                if m["is_target"]: m["total"] += 1
                
            hr = now.hour
            idx = hr * 2 + (1 if now.minute >= 30 else 0)
            if 0 <= idx < 48: d["hourly"][idx] += 1
                
            day_idx = now.weekday()
            if 0 <= hr < 24: d["week_heatmap"][day_idx][hr] += 1
                
        # Conditionally write to tmpfs
        if write_to_disk:
            temp_file = STATE_FILE + ".tmp"
            try:
                with open(temp_file, "w") as f:
                    json.dump(self.cached_json, f)
                os.rename(temp_file, STATE_FILE)
            except Exception:
                pass
            
        if len(self.buffer) >= 15:
            self.flush()
            
    def flush(self):
        if not self.buffer: return
        c = self.conn.cursor()
        
        logs = defaultdict(int)
        titles = {}
        hours = defaultdict(int)
        intervals = defaultdict(int)
        minutes = defaultdict(int)
        
        for d_str, cls, title, dt in self.buffer:
            logs[(d_str, cls)] += 1
            titles[cls] = title
            hr = dt.hour
            hours[(d_str, hr, cls)] += 1
            minute = hr * 60 + dt.minute
            intervals[(d_str, minute // 15, cls)] += 1
            minutes[(d_str, minute, cls)] += 1
            
        for (d_str, cls), secs in logs.items():
            c.execute('''INSERT INTO focus_log (log_date, app_class, seconds, app_title) VALUES (?, ?, ?, ?)
                         ON CONFLICT(log_date, app_class) DO UPDATE SET seconds = seconds + ?, app_title = ?''',
                      (d_str, cls, secs, titles[cls], secs, titles[cls]))
                      
        for (d_str, hr, cls), secs in hours.items():
            c.execute('''INSERT INTO focus_hourly (log_date, hour, app_class, seconds) VALUES (?, ?, ?, ?)
                         ON CONFLICT(log_date, hour, app_class) DO UPDATE SET seconds = seconds + ?''',
                      (d_str, hr, cls, secs, secs))
                      
        for (d_str, itv, cls), secs in intervals.items():
            c.execute('''INSERT INTO focus_intervals (log_date, interval_idx, app_class, seconds) VALUES (?, ?, ?, ?)
                         ON CONFLICT(log_date, interval_idx, app_class) DO UPDATE SET seconds = seconds + ?''',
                      (d_str, itv, cls, secs, secs))
                      
        for (d_str, min_idx, cls), secs in minutes.items():
            c.execute('''INSERT INTO focus_minutes (log_date, minute_idx, app_class, seconds) VALUES (?, ?, ?, ?)
                         ON CONFLICT(log_date, minute_idx, app_class) DO UPDATE SET seconds = seconds + ?''',
                      (d_str, min_idx, cls, secs, secs))
                      
        self.conn.commit()
        self.buffer.clear()

tracker = DaemonTracker()

def exit_handler(sig, frame):
    tracker.flush()
    sys.exit(0)

def heal(limit_days=None):
    """One-shot backfill. Re-resolves stored rows with the current resolution
    rules and folds system-infrastructure rows (xdg-desktop-portal dialogs)
    into the Desktop bucket. Seconds totals are preserved; only display
    identity changes."""
    build_desktop_cache()
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    if limit_days:
        c.execute("SELECT log_date, app_class, app_title, seconds FROM focus_log WHERE log_date >= date('now', ?)",
                  (f"-{limit_days} days",))
    else:
        c.execute("SELECT log_date, app_class, app_title, seconds FROM focus_log")
    rows = c.fetchall()

    retitled = 0
    folded = 0
    for log_date, app_class, app_title, seconds in rows:
        if is_portal_class(app_class):
            c.execute('''INSERT INTO focus_log (log_date, app_class, seconds, app_title)
                         VALUES (?, 'Desktop', ?, 'Desktop')
                         ON CONFLICT(log_date, app_class) DO UPDATE SET seconds = seconds + ?''',
                      (log_date, seconds, seconds))
            c.execute("DELETE FROM focus_log WHERE log_date = ? AND app_class = ?", (log_date, app_class))
            folded += 1
            continue
        # Conservative: only retitle rows whose stored title is provably bad
        # (placeholder, URL-ish fallback, >25-char garbage, or a PWA row whose
        # title equals its class). Good titles are left untouched so re-running
        # resolution can never replace them with a worse result.
        title = app_title or app_class
        is_bad = (title.lower() in PLACEHOLDER_TITLES
                  or looks_like_host(title)
                  or len(title) > 25
                  or (title == app_class and pwa_host_from_class(app_class) is not None))
        if not is_bad:
            continue
        new_name = resolve_app_name(app_class, title)
        if new_name != title:
            c.execute("UPDATE focus_log SET app_title = ? WHERE log_date = ? AND app_class = ?",
                      (new_name, log_date, app_class))
            retitled += 1
    conn.commit()
    conn.close()
    print(f"heal: {retitled} rows retitled, {folded} portal rows folded into Desktop")

def main():
    global current_app_class, current_app_title
    parser = argparse.ArgumentParser()
    parser.add_argument("--heal", action="store_true", help="One-shot backfill of focus_log titles")
    parser.add_argument("--heal-days", type=int, default=None, help="Heal only the last N days")
    args = parser.parse_args()

    if args.heal:
        heal(args.heal_days)
        return

    signal.signal(signal.SIGINT, exit_handler)
    signal.signal(signal.SIGTERM, exit_handler)

    resolve_hypr_signature()
    with _state_lock:
        current_app_class, current_app_title = get_active_window_hyprctl()

    ipc_thread = threading.Thread(target=listen_hyprland_ipc, daemon=True)
    ipc_thread.start()

    tick_counter = 0
    while True:
        time.sleep(1)
        tick_counter += 1

        # Polled lock-state safety net, independent of the IPC event stream.
        # Catches cases where hyprlock is invoked without an intervening
        # Hyprland activewindow change (e.g. certain idle-triggered lock
        # paths), which the event-driven check in listen_hyprland_ipc()
        # would otherwise miss until the next real window switch.
        with _state_lock:
            if current_app_class != "Locked" and is_locked():
                current_app_class, current_app_title = "Locked", "Locked"
            cls_snapshot = current_app_class
            title_snapshot = current_app_title
            connected = hyprland_connected

        # Only record time while the Hyprland event socket is actually
        # connected. After a Hyprland restart the IPC thread re-resolves
        # the instance signature and reconnects within ~2s; between the
        # restart and reconnect nothing is attributed to "Unknown".
        if connected and cls_snapshot and cls_snapshot not in [""]:
            # Only dump JSON to memory/disk every 5 seconds
            tracker.fast_tick(cls_snapshot, title_snapshot, write_to_disk=(tick_counter % 5 == 0))
            
if __name__ == "__main__":
    main()
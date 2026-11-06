mod common;

use chrono::{Local, Timelike};
use rusqlite::Connection;
use serde::Serialize;
use std::collections::HashMap;
use std::fs;
use std::io::{BufRead, BufReader};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

#[derive(Serialize, Clone)]
struct LiveState {
    current_app_class: String,
    current_app_title: String,
    today_total: i64,
    last_updated: String,
}

fn resolve_hypr_socket() -> Option<PathBuf> {
    let runtime_dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());
    if let Ok(sig) = std::env::var("HYPRLAND_INSTANCE_SIGNATURE") {
        let candidate = PathBuf::from(&runtime_dir).join("hypr").join(&sig).join(".socket2.sock");
        if candidate.exists() {
            return Some(candidate);
        }
    }

    let hypr_base = PathBuf::from(&runtime_dir).join("hypr");
    if let Ok(entries) = fs::read_dir(hypr_base) {
        for entry in entries.flatten() {
            let p = entry.path().join(".socket2.sock");
            if p.exists() {
                return Some(p);
            }
        }
    }
    None
}

fn is_locked() -> bool {
    if let Ok(entries) = fs::read_dir("/proc") {
        for entry in entries.flatten() {
            let name = entry.file_name();
            if let Some(s) = name.to_str() {
                if s.chars().all(|c| c.is_ascii_digit()) {
                    let comm_path = entry.path().join("comm");
                    if let Ok(comm) = fs::read_to_string(comm_path) {
                        if comm.trim() == "hyprlock" {
                            return true;
                        }
                    }
                }
            }
        }
    }
    false
}

fn query_active_window() -> (String, String) {
    let output = match std::process::Command::new("hyprctl")
        .args(["activewindow", "-j"])
        .output()
    {
        Ok(out) => out,
        Err(_) => return ("Desktop".to_string(), "Desktop".to_string()),
    };

    let text = String::from_utf8_lossy(&output.stdout);
    if text.trim() == "{}" || text.trim().is_empty() {
        return ("Desktop".to_string(), "Desktop".to_string());
    }

    if let Ok(val) = serde_json::from_str::<serde_json::Value>(&text) {
        let cls = val.get("class")
            .and_then(|v| v.as_str())
            .or_else(|| val.get("initialClass").and_then(|v| v.as_str()))
            .unwrap_or("")
            .to_string();
        let title = val.get("title")
            .and_then(|v| v.as_str())
            .or_else(|| val.get("initialTitle").and_then(|v| v.as_str()))
            .unwrap_or("")
            .to_string();

        let cls_lower = cls.to_lowercase();
        let title_lower = title.to_lowercase();
        if cls_lower.contains("quickshell") || title_lower.contains("qs-master") || cls_lower.contains("qs-master") {
            return ("Quickshell".to_string(), "Quickshell".to_string());
        }
        if common::is_system_class(&cls) {
            return ("Desktop".to_string(), "Desktop".to_string());
        }

        let app_cls = if cls.is_empty() { "Unknown".to_string() } else { cls };
        let mut cache = common::DESKTOP_CACHE.lock().unwrap();
        let clean_name = cache.resolve_app_name(&app_cls, &title);
        return (app_cls, clean_name);
    }

    ("Unknown".to_string(), "Unknown".to_string())
}

struct TickRecord {
    date_str: String,
    cls: String,
    title: String,
    hour: u32,
    minute_idx: u32,
}

fn flush_buffer(conn: &mut Connection, buffer: &mut Vec<TickRecord>) {
    if buffer.is_empty() {
        return;
    }

    let tx = match conn.transaction() {
        Ok(t) => t,
        Err(e) => {
            eprintln!("Failed to begin transaction: {}", e);
            return;
        }
    };

    let mut logs: HashMap<(String, String), (i64, String)> = HashMap::new();
    let mut hours: HashMap<(String, u32, String), i64> = HashMap::new();
    let mut intervals: HashMap<(String, u32, String), i64> = HashMap::new();
    let mut minutes: HashMap<(String, u32, String), i64> = HashMap::new();

    for rec in buffer.drain(..) {
        let entry = logs.entry((rec.date_str.clone(), rec.cls.clone())).or_insert((0, rec.title.clone()));
        entry.0 += 1;
        entry.1 = rec.title.clone();

        *hours.entry((rec.date_str.clone(), rec.hour, rec.cls.clone())).or_insert(0) += 1;
        *intervals.entry((rec.date_str.clone(), rec.minute_idx / 15, rec.cls.clone())).or_insert(0) += 1;
        *minutes.entry((rec.date_str, rec.minute_idx, rec.cls)).or_insert(0) += 1;
    }

    for ((d_str, cls), (secs, title)) in logs {
        let _ = tx.execute(
            "INSERT INTO focus_log (log_date, app_class, seconds, app_title) VALUES (?, ?, ?, ?)
             ON CONFLICT(log_date, app_class) DO UPDATE SET seconds = seconds + ?, app_title = ?",
            rusqlite::params![d_str, cls, secs, title, secs, title],
        );
    }

    for ((d_str, hr, cls), secs) in hours {
        let _ = tx.execute(
            "INSERT INTO focus_hourly (log_date, hour, app_class, seconds) VALUES (?, ?, ?, ?)
             ON CONFLICT(log_date, hour, app_class) DO UPDATE SET seconds = seconds + ?",
            rusqlite::params![d_str, hr, cls, secs, secs],
        );
    }

    for ((d_str, itv, cls), secs) in intervals {
        let _ = tx.execute(
            "INSERT INTO focus_intervals (log_date, interval_idx, app_class, seconds) VALUES (?, ?, ?, ?)
             ON CONFLICT(log_date, interval_idx, app_class) DO UPDATE SET seconds = seconds + ?",
            rusqlite::params![d_str, itv, cls, secs, secs],
        );
    }

    for ((d_str, min_idx, cls), secs) in minutes {
        let _ = tx.execute(
            "INSERT INTO focus_minutes (log_date, minute_idx, app_class, seconds) VALUES (?, ?, ?, ?)
             ON CONFLICT(log_date, minute_idx, app_class) DO UPDATE SET seconds = seconds + ?",
            rusqlite::params![d_str, min_idx, cls, secs, secs],
        );
    }

    let _ = tx.commit();
}

fn main() {
    let db_path = common::get_db_path();
    if let Some(parent) = db_path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let mut conn = match Connection::open(&db_path) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Failed to open DB at {:?}: {}", db_path, e);
            std::process::exit(1);
        }
    };

    if let Err(e) = common::init_db(&conn) {
        eprintln!("Failed to init DB: {}", e);
        std::process::exit(1);
    }

    let run_dir = std::env::var("QS_RUN_FOCUSTIME").unwrap_or_else(|_| "/tmp/quickshell/focustime".to_string());
    let _ = fs::create_dir_all(&run_dir);
    let state_file = PathBuf::from(&run_dir).join("focustime_state.json");

    let current_window = Arc::new(Mutex::new(("Desktop".to_string(), "Desktop".to_string())));
    let hypr_connected = Arc::new(AtomicBool::new(false));

    // Background thread listening to Hyprland IPC socket
    {
        let current_window = Arc::clone(&current_window);
        let hypr_connected = Arc::clone(&hypr_connected);
        thread::spawn(move || {
            loop {
                if let Some(sock_path) = resolve_hypr_socket() {
                    if let Ok(stream) = UnixStream::connect(sock_path) {
                        hypr_connected.store(true, Ordering::SeqCst);
                        let reader = BufReader::new(stream);
                        for line in reader.lines().map_while(Result::ok) {
                            if line.starts_with("activewindow>>") {
                                let (cls, title) = query_active_window();
                                let mut cur = current_window.lock().unwrap();
                                *cur = (cls, title);
                            }
                        }
                    }
                }
                hypr_connected.store(false, Ordering::SeqCst);
                thread::sleep(Duration::from_secs(2));
            }
        });
    }

    let mut buffer: Vec<TickRecord> = Vec::new();
    let mut today_total: i64 = 0;
    let mut last_date = Local::now().date_naive().format("%Y-%m-%d").to_string();

    // Query today total initially
    if let Ok(tot) = conn.query_row(
        "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = ?",
        [&last_date],
        |r| r.get::<_, i64>(0),
    ) {
        today_total = tot;
    }

    let term = Arc::new(AtomicBool::new(false));
    let _ = signal_hook::flag::register(signal_hook::consts::SIGINT, Arc::clone(&term));
    let _ = signal_hook::flag::register(signal_hook::consts::SIGTERM, Arc::clone(&term));
    let mut last_live_write = Instant::now();
    let mut last_live_app: Option<(String, String)> = None;

    while !term.load(Ordering::SeqCst) {
        thread::sleep(Duration::from_secs(1));

        let now = Local::now();
        let date_str = now.date_naive().format("%Y-%m-%d").to_string();
        if date_str != last_date {
            flush_buffer(&mut conn, &mut buffer);
            last_date = date_str.clone();
            today_total = 0;
        }

        let (cls, title) = if is_locked() {
            ("Locked".to_string(), "Locked".to_string())
        } else {
            let cur = current_window.lock().unwrap();
            cur.clone()
        };

        if cls != "Desktop" && cls != "Unknown" && cls != "Quickshell" {
            today_total += 1;
        }

        let hour = now.hour();
        let minute_idx = hour * 60 + now.minute();

        buffer.push(TickRecord {
            date_str,
            cls: cls.clone(),
            title: title.clone(),
            hour,
            minute_idx,
        });

        // Publish immediately when the focused app changes, then coalesce the
        // changing live total to a 15-second update. Tick accounting stays 1s.
        let app = (cls.clone(), title.clone());
        if last_live_app.as_ref() != Some(&app)
            || last_live_write.elapsed() >= Duration::from_secs(15)
        {
            let live = LiveState {
                current_app_class: cls,
                current_app_title: title,
                today_total,
                last_updated: now.to_rfc3339(),
            };
            let tmp_file = format!("{}.tmp.{}", state_file.display(), std::process::id());
            if let Ok(json_str) = serde_json::to_string(&live) {
                if fs::write(&tmp_file, json_str).is_ok() {
                    let _ = fs::rename(&tmp_file, &state_file);
                    last_live_write = Instant::now();
                    last_live_app = Some(app);
                }
            }
        }

        if buffer.len() >= 60 {
            flush_buffer(&mut conn, &mut buffer);
        }
    }

    flush_buffer(&mut conn, &mut buffer);
}

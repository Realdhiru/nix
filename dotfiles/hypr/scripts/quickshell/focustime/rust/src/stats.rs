mod common;

use chrono::{Datelike, Duration, Local, NaiveDate};
use rusqlite::{types::ToSql, Connection};
use serde::Serialize;
use std::collections::HashMap;
use std::path::PathBuf;

#[derive(Serialize)]
struct AppStat {
    class: String,
    name: String,
    icon: String,
    seconds: i64,
    percent: f64,
}

#[derive(Serialize)]
struct DayStat {
    date: String,
    day: String,
    total: i64,
    is_target: bool,
}

#[derive(Serialize)]
struct MonthStat {
    date: String,
    total: i64,
    is_target: bool,
}

#[derive(Serialize)]
struct StatsOutput {
    selected_date: String,
    total: i64,
    average: i64,
    week_range: String,
    yesterday: i64,
    current: String,
    apps: Vec<AppStat>,
    week_apps: Vec<AppStat>,
    week: Vec<DayStat>,
    month: Vec<MonthStat>,
    hourly: Vec<i64>,
    week_heatmap: Vec<Vec<i64>>,
    peak_usage_str: String,
}

fn main() {
    let mut args = std::env::args().skip(1);
    let mut target_date_str = None;
    let mut app_filter = None;
    let mut db_dir = None;

    while let Some(arg) = args.next() {
        if arg == "--app" {
            app_filter = args.next();
        } else if arg == "--db-dir" {
            db_dir = args.next();
        } else if !arg.starts_with('-') && target_date_str.is_none() {
            target_date_str = Some(arg);
        }
    }

    let today = Local::now().date_naive();
    let target_date = target_date_str
        .and_then(|s| NaiveDate::parse_from_str(&s, "%Y-%m-%d").ok())
        .unwrap_or(today);

    let db_path = if let Some(d) = db_dir {
        PathBuf::from(d).join("focustime.db")
    } else {
        common::get_db_path()
    };

    if !db_path.exists() {
        let empty = StatsOutput {
            selected_date: target_date.format("%Y-%m-%d").to_string(),
            total: 0,
            average: 0,
            week_range: String::new(),
            yesterday: 0,
            current: app_filter.unwrap_or_else(|| "History".to_string()),
            apps: vec![],
            week_apps: vec![],
            week: vec![],
            month: vec![],
            hourly: vec![0; 48],
            week_heatmap: vec![vec![0; 24]; 7],
            peak_usage_str: "N/A".to_string(),
        };
        println!("{}", serde_json::to_string(&empty).unwrap());
        return;
    }

    let conn = match Connection::open(&db_path) {
        Ok(c) => c,
        Err(_) => {
            eprintln!("Failed to open DB at {:?}", db_path);
            return;
        }
    };

    let cache = common::DESKTOP_CACHE.lock().unwrap();

    let target_str = target_date.format("%Y-%m-%d").to_string();
    let yesterday_date = target_date - Duration::days(1);
    let yesterday_str = yesterday_date.format("%Y-%m-%d").to_string();

    // Yesterday seconds
    let yesterday_seconds: i64 = match &app_filter {
        Some(app) => conn.query_row(
            "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = ? AND app_class = ?",
            [&yesterday_str, app],
            |r| r.get(0),
        ),
        None => conn.query_row(
            "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = ?",
            [&yesterday_str],
            |r| r.get(0),
        ),
    }.unwrap_or(0);

    // Week boundaries (Monday..Sunday)
    let days_from_monday = target_date.weekday().num_days_from_monday() as i64;
    let monday = target_date - Duration::days(days_from_monday);
    let sunday = monday + Duration::days(6);
    let monday_str = monday.format("%Y-%m-%d").to_string();
    let sunday_str = sunday.format("%Y-%m-%d").to_string();

    let week_range_str = format!("{} {} - {} {}", monday.format("%b"), monday.day(), sunday.format("%b"), sunday.day());

    // Average seconds
    let (days_count, total_week): (i64, i64) = match &app_filter {
        Some(app) => conn.query_row(
            "SELECT COUNT(DISTINCT log_date), COALESCE(SUM(seconds), 0) FROM focus_log
             WHERE log_date >= ? AND log_date <= ? AND seconds > 0 AND app_class = ?",
            [&monday_str, &sunday_str, app],
            |r| Ok((r.get(0)?, r.get(1)?)),
        ),
        None => conn.query_row(
            "SELECT COUNT(DISTINCT log_date), COALESCE(SUM(seconds), 0) FROM focus_log
             WHERE log_date >= ? AND log_date <= ? AND seconds > 0",
            [&monday_str, &sunday_str],
            |r| Ok((r.get(0)?, r.get(1)?)),
        ),
    }.unwrap_or((0, 0));

    let average_seconds = if days_count > 0 { total_week / days_count } else { 0 };

    // Total seconds for target date
    let total_seconds: i64 = match &app_filter {
        Some(app) => conn.query_row(
            "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = ? AND app_class = ?",
            [&target_str, app],
            |r| r.get(0),
        ),
        None => conn.query_row(
            "SELECT COALESCE(SUM(seconds), 0) FROM focus_log WHERE log_date = ?",
            [&target_str],
            |r| r.get(0),
        ),
    }.unwrap_or(0);

    // Apps for target date
    let mut all_apps = Vec::new();
    {
        let query = if app_filter.is_some() {
            "SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log WHERE log_date = ? AND app_class = ? GROUP BY app_class ORDER BY secs DESC"
        } else {
            "SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log WHERE log_date = ? GROUP BY app_class ORDER BY secs DESC"
        };
        let mut stmt = conn.prepare(query).unwrap();
        let params: Vec<&dyn ToSql> = if let Some(app) = &app_filter {
            vec![&target_str, app]
        } else {
            vec![&target_str]
        };
        let mut rows = stmt.query(params.as_slice()).unwrap();
        while let Ok(Some(row)) = rows.next() {
            let cls: String = row.get(0).unwrap_or_default();
            let title: String = row.get(1).unwrap_or_default();
            let secs: i64 = row.get(2).unwrap_or(0);
            if secs == 0 { continue; }
            let icon = cache.get_app_icon(&cls);
            let percent = if total_seconds > 0 {
                ((secs as f64 / total_seconds as f64) * 1000.0).round() / 10.0
            } else {
                0.0
            };
            all_apps.push(AppStat {
                class: cls,
                name: title,
                icon,
                seconds: secs,
                percent,
            });
        }
    }

    // Week apps
    let mut week_apps = Vec::new();
    {
        let query = if app_filter.is_some() {
            "SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log WHERE log_date >= ? AND log_date <= ? AND app_class = ? GROUP BY app_class ORDER BY secs DESC LIMIT 50"
        } else {
            "SELECT app_class, COALESCE(app_title, app_class), SUM(seconds) as secs FROM focus_log WHERE log_date >= ? AND log_date <= ? GROUP BY app_class ORDER BY secs DESC LIMIT 50"
        };
        let mut stmt = conn.prepare(query).unwrap();
        let params: Vec<&dyn ToSql> = if let Some(app) = &app_filter {
            vec![&monday_str, &sunday_str, app]
        } else {
            vec![&monday_str, &sunday_str]
        };
        let mut rows = stmt.query(params.as_slice()).unwrap();
        let mut week_apps_rows = Vec::new();
        while let Ok(Some(row)) = rows.next() {
            let cls: String = row.get(0).unwrap_or_default();
            let title: String = row.get(1).unwrap_or_default();
            let secs: i64 = row.get(2).unwrap_or(0);
            week_apps_rows.push((cls, title, secs));
        }
        let week_apps_total: i64 = week_apps_rows.iter().map(|r| r.2).sum();
        for (cls, title, secs) in week_apps_rows {
            if secs == 0 { continue; }
            let icon = cache.get_app_icon(&cls);
            let percent = if week_apps_total > 0 {
                ((secs as f64 / week_apps_total as f64) * 1000.0).round() / 10.0
            } else {
                0.0
            };
            week_apps.push(AppStat {
                class: cls,
                name: title,
                icon,
                seconds: secs,
                percent,
            });
        }
    }

    // Bulk query for week days
    let mut week_map: HashMap<String, i64> = HashMap::new();
    {
        let query = if app_filter.is_some() {
            "SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? AND app_class = ? GROUP BY log_date"
        } else {
            "SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? GROUP BY log_date"
        };
        let mut stmt = conn.prepare(query).unwrap();
        let params: Vec<&dyn ToSql> = if let Some(app) = &app_filter {
            vec![&monday_str, &sunday_str, app]
        } else {
            vec![&monday_str, &sunday_str]
        };
        let mut rows = stmt.query(params.as_slice()).unwrap();
        while let Ok(Some(row)) = rows.next() {
            let d_str: String = row.get(0).unwrap_or_default();
            let secs: i64 = row.get(1).unwrap_or(0);
            week_map.insert(d_str, secs);
        }
    }

    let days_str = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    let mut week_data = Vec::new();
    for i in 0..7 {
        let d = monday + Duration::days(i);
        let d_str = d.format("%Y-%m-%d").to_string();
        let is_target = d_str == target_str;
        let total = *week_map.get(&d_str).unwrap_or(&0);
        week_data.push(DayStat {
            date: d_str,
            day: days_str[i as usize].to_string(),
            total,
            is_target,
        });
    }

    // Bulk query for month
    let first_day = NaiveDate::from_ymd_opt(target_date.year(), target_date.month(), 1).unwrap();
    let next_month = if target_date.month() == 12 {
        NaiveDate::from_ymd_opt(target_date.year() + 1, 1, 1).unwrap()
    } else {
        NaiveDate::from_ymd_opt(target_date.year(), target_date.month() + 1, 1).unwrap()
    };
    let last_day = next_month - Duration::days(1);
    let first_day_str = first_day.format("%Y-%m-%d").to_string();
    let last_day_str = last_day.format("%Y-%m-%d").to_string();

    let mut month_map: HashMap<String, i64> = HashMap::new();
    {
        let query = if app_filter.is_some() {
            "SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? AND app_class = ? GROUP BY log_date"
        } else {
            "SELECT log_date, SUM(seconds) FROM focus_log WHERE log_date >= ? AND log_date <= ? GROUP BY log_date"
        };
        let mut stmt = conn.prepare(query).unwrap();
        let params: Vec<&dyn ToSql> = if let Some(app) = &app_filter {
            vec![&first_day_str, &last_day_str, app]
        } else {
            vec![&first_day_str, &last_day_str]
        };
        let mut rows = stmt.query(params.as_slice()).unwrap();
        while let Ok(Some(row)) = rows.next() {
            let d_str: String = row.get(0).unwrap_or_default();
            let secs: i64 = row.get(1).unwrap_or(0);
            month_map.insert(d_str, secs);
        }
    }

    let mut month_data = Vec::new();
    let pad_days = first_day.weekday().num_days_from_monday();
    for _ in 0..pad_days {
        month_data.push(MonthStat {
            date: String::new(),
            total: -1,
            is_target: false,
        });
    }
    for day in 1..=last_day.day() {
        let d = NaiveDate::from_ymd_opt(target_date.year(), target_date.month(), day).unwrap();
        let d_str = d.format("%Y-%m-%d").to_string();
        let is_target = d_str == target_str;
        let total = *month_map.get(&d_str).unwrap_or(&0);
        month_data.push(MonthStat {
            date: d_str,
            total,
            is_target,
        });
    }

    // Hourly
    let mut hourly_data = vec![0i64; 48];
    {
        let q1 = if app_filter.is_some() {
            "SELECT hour, SUM(seconds) FROM focus_hourly WHERE log_date = ? AND app_class = ? GROUP BY hour"
        } else {
            "SELECT hour, SUM(seconds) FROM focus_hourly WHERE log_date = ? GROUP BY hour"
        };
        if let Ok(mut stmt) = conn.prepare(q1) {
            let params: Vec<&dyn ToSql> = if let Some(app) = &app_filter {
                vec![&target_str, app]
            } else {
                vec![&target_str]
            };
            if let Ok(mut rows) = stmt.query(params.as_slice()) {
                while let Ok(Some(row)) = rows.next() {
                    let hr: i64 = row.get(0).unwrap_or(-1);
                    let secs: i64 = row.get(1).unwrap_or(0);
                    if hr >= 0 && hr <= 23 {
                        hourly_data[(hr * 2) as usize] += secs;
                    }
                }
            }
        }

        let q2 = if app_filter.is_some() {
            "SELECT interval_idx, SUM(seconds) FROM focus_intervals WHERE log_date = ? AND app_class = ? GROUP BY interval_idx"
        } else {
            "SELECT interval_idx, SUM(seconds) FROM focus_intervals WHERE log_date = ? GROUP BY interval_idx"
        };
        if let Ok(mut stmt) = conn.prepare(q2) {
            let params: Vec<&dyn ToSql> = if let Some(app) = &app_filter {
                vec![&target_str, app]
            } else {
                vec![&target_str]
            };
            if let Ok(mut rows) = stmt.query(params.as_slice()) {
                while let Ok(Some(row)) = rows.next() {
                    let idx: i64 = row.get(0).unwrap_or(-1);
                    let secs: i64 = row.get(1).unwrap_or(0);
                    if idx >= 0 && idx < 96 {
                        hourly_data[(idx / 2) as usize] += secs;
                    }
                }
            }
        }
    }

    // Week heatmap
    let mut week_heatmap = vec![vec![0i64; 24]; 7];
    {
        let query = if app_filter.is_some() {
            "SELECT log_date, hour, SUM(seconds) FROM focus_hourly WHERE log_date >= ? AND log_date <= ? AND app_class = ? GROUP BY log_date, hour"
        } else {
            "SELECT log_date, hour, SUM(seconds) FROM focus_hourly WHERE log_date >= ? AND log_date <= ? GROUP BY log_date, hour"
        };
        if let Ok(mut stmt) = conn.prepare(query) {
            let params: Vec<&dyn ToSql> = if let Some(app) = &app_filter {
                vec![&monday_str, &sunday_str, app]
            } else {
                vec![&monday_str, &sunday_str]
            };
            if let Ok(mut rows) = stmt.query(params.as_slice()) {
                while let Ok(Some(row)) = rows.next() {
                    let ldate: String = row.get(0).unwrap_or_default();
                    let hr: i64 = row.get(1).unwrap_or(-1);
                    let secs: i64 = row.get(2).unwrap_or(0);
                    if let Ok(parsed) = NaiveDate::parse_from_str(&ldate, "%Y-%m-%d") {
                        let day_idx = parsed.weekday().num_days_from_monday() as usize;
                        if hr >= 0 && hr <= 23 && day_idx < 7 {
                            week_heatmap[day_idx][hr as usize] += secs;
                        }
                    }
                }
            }
        }
    }

    // Minute data and peak calculation
    let mut minute_data = vec![0i64; 1440];
    {
        let query = if app_filter.is_some() {
            "SELECT minute_idx, SUM(seconds) FROM focus_minutes WHERE log_date >= ? AND log_date <= ? AND app_class = ? GROUP BY minute_idx"
        } else {
            "SELECT minute_idx, SUM(seconds) FROM focus_minutes WHERE log_date >= ? AND log_date <= ? GROUP BY minute_idx"
        };
        if let Ok(mut stmt) = conn.prepare(query) {
            let params: Vec<&dyn ToSql> = if let Some(app) = &app_filter {
                vec![&monday_str, &sunday_str, app]
            } else {
                vec![&monday_str, &sunday_str]
            };
            if let Ok(mut rows) = stmt.query(params.as_slice()) {
                while let Ok(Some(row)) = rows.next() {
                    let idx: i64 = row.get(0).unwrap_or(-1);
                    let secs: i64 = row.get(1).unwrap_or(0);
                    if idx >= 0 && idx < 1440 {
                        minute_data[idx as usize] += secs;
                    }
                }
            }
        }
    }

    let mut peak_str = "N/A".to_string();
    let mut max_sum = 0i64;
    let mut best_window = None;

    if minute_data.len() >= 60 {
        let mut cur_sum: i64 = minute_data[0..60].iter().sum();
        if cur_sum > max_sum && cur_sum > 0 {
            max_sum = cur_sum;
            best_window = Some((0, 60));
        }
        for i in 1..=(1440 - 60) {
            cur_sum = cur_sum - minute_data[i - 1] + minute_data[i + 59];
            if cur_sum > max_sum && cur_sum > 0 {
                max_sum = cur_sum;
                best_window = Some((i, i + 60));
            }
        }
    }

    if let Some((mut start_idx, end_idx)) = best_window {
        while start_idx < end_idx && minute_data[start_idx] == 0 {
            start_idx += 1;
        }
        let mut actual_end = end_idx - 1;
        while actual_end > start_idx && minute_data[actual_end] == 0 {
            actual_end -= 1;
        }
        let (s_h, s_m) = (start_idx / 60, start_idx % 60);
        let (e_h, e_m) = (actual_end / 60, actual_end % 60);
        peak_str = format!("{:02}:{:02} - {:02}:{:02}", s_h, s_m, e_h, e_m);
    }

    let output = StatsOutput {
        selected_date: target_str,
        total: total_seconds,
        average: average_seconds,
        week_range: week_range_str,
        yesterday: yesterday_seconds,
        current: app_filter.unwrap_or_else(|| "History".to_string()),
        apps: all_apps,
        week_apps,
        week: week_data,
        month: month_data,
        hourly: hourly_data,
        week_heatmap,
        peak_usage_str: peak_str,
    };

    println!("{}", serde_json::to_string(&output).unwrap());
}

#!/usr/bin/env python3
import json
import os
import re
import time
from datetime import datetime, timedelta
from selenium import webdriver
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException

# --- CONFIGURATION ---
BASE_URL = "https://all.uddataplus.dk/skema/?id=id_menu_skema"
RESOURCE_ID = "99217" 
PROFILE_PATH = "/home/ilyamiro/.mozilla/firefox/schedule.special"

CACHE_DIR = os.environ.get("QS_CACHE_SCHEDULE", os.path.expanduser("~/.cache/quickshell/schedule"))
CACHE_FILE = os.path.join(CACHE_DIR, "schedule.json")

# Time Configuration (24-hour format)
SCHOOL_START_STR = "08:30"
SCHOOL_END_STR = "15:40"

# Layout Configuration
TOTAL_AVAILABLE_WIDTH_PX = 750 

# Base URLs
GENERIC_URL = f"{BASE_URL}#menu_skema:"
BASE_LINK_URL = BASE_URL

def get_specific_url(date_obj):
    date_str = date_obj.strftime("%Y-%m-%d")
    return f"{BASE_LINK_URL}#u:e!{RESOURCE_ID}!{date_str}"

def to_epoch(time_str, date_obj):
    try:
        clean_time = time_str.replace('.', ':').strip()
        hour, minute = map(int, clean_time.split(':'))
        dt = date_obj.replace(hour=hour, minute=minute, second=0, microsecond=0)
        return int(dt.timestamp())
    except Exception as e:
        return 0

def calculate_ppm():
    start_h, start_m = map(int, SCHOOL_START_STR.replace('.', ':').split(':'))
    end_h, end_m = map(int, SCHOOL_END_STR.replace('.', ':').split(':'))
    start_minutes = start_h * 60 + start_m
    end_minutes = end_h * 60 + end_m
    total_minutes = end_minutes - start_minutes
    if total_minutes <= 0: return 1.5 
    return TOTAL_AVAILABLE_WIDTH_PX / total_minutes

PIXELS_PER_MINUTE = calculate_ppm()

def extract_lessons_from_group(group, date_obj):
    raw_lessons = []
    processed_data = []
    
    lesson_elems = group.find_elements(By.XPATH, ".//*[local-name()='g'][count(*[local-name()='rect']) > 0]")
    
    for elem in lesson_elems:
        try:
            texts = elem.find_elements(By.TAG_NAME, "text")
            if len(texts) >= 3:
                time_raw = texts[0].text.strip()
                if "-" in time_raw:
                    start_str, end_str = time_raw.split('-')
                    teacher_str = ""
                    if len(texts) >= 4:
                        teacher_str = texts[3].text
                    
                    if texts[1].text != "Lektiecafe": 
                        start_epoch = to_epoch(start_str, date_obj)
                        end_epoch = to_epoch(end_str, date_obj)
                        
                        if start_epoch > 0 and end_epoch > 0:
                            raw_lessons.append({
                                "type": "class", 
                                "time": time_raw,
                                "subject": texts[1].text,
                                "room": texts[2].text,
                                "teacher": teacher_str,
                                "start": start_epoch,
                                "end": end_epoch
                            })
        except:
            continue

    raw_lessons.sort(key=lambda x: x['start'])

    start_h, start_m = map(int, SCHOOL_START_STR.replace('.', ':').split(':'))
    end_h, end_m = map(int, SCHOOL_END_STR.replace('.', ':').split(':'))
    
    timeline_start = date_obj.replace(hour=start_h, minute=start_m, second=0, microsecond=0)
    timeline_end = date_obj.replace(hour=end_h, minute=end_m, second=0, microsecond=0)
    
    current_cursor = int(timeline_start.timestamp())
    standard_end_cursor = int(timeline_end.timestamp())

    def get_layout_props(duration_seconds):
        duration_seconds = max(0, duration_seconds)
        minutes = duration_seconds / 60
        width = minutes * PIXELS_PER_MINUTE
        char_limit = int(width / 5) 
        return int(width), char_limit

    for lesson in raw_lessons:
        if lesson['start'] > current_cursor:
            gap_duration = lesson['start'] - current_cursor
            if gap_duration > 60: 
                width, _ = get_layout_props(gap_duration)
                gap_minutes = int(gap_duration / 60)
                processed_data.append({
                    "type": "gap",
                    "width": width,
                    "desc": f"{gap_minutes}m",
                    "start": current_cursor,
                    "end": lesson['start']
                })
            current_cursor = lesson['start']
        
        if lesson['end'] <= int(timeline_start.timestamp()):
            continue

        if lesson['start'] >= current_cursor:
            duration = lesson['end'] - current_cursor
            width, char_limit = get_layout_props(duration)
            lesson["width"] = width
            lesson["char_limit"] = char_limit
            lesson["is_compact"] = width < 70
            processed_data.append(lesson)
            current_cursor = lesson['end']

    if current_cursor < standard_end_cursor:
        gap_duration = standard_end_cursor - current_cursor
        if gap_duration > 60:
            width, _ = get_layout_props(gap_duration)
            processed_data.append({
                "type": "gap",
                "width": width,
                "desc": "End of Day",
                "start": current_cursor,
                "end": standard_end_cursor
            })

    return processed_data

def get_valid_day_columns(driver):
    try:
        wait = WebDriverWait(driver, 3)
        wait.until(EC.presence_of_element_located((By.CLASS_NAME, "skemaBrikGruppe")))
        groups = driver.find_elements(By.XPATH, "//*[contains(@class, 'DagMedBrikker')]//*[contains(@class, 'skemaBrikGruppe')]/..")
        def get_x_pos(elem):
            transform = elem.get_attribute("transform")
            if not transform: return 99999
            match = re.search(r"translate\((\d+)", transform)
            return int(match.group(1)) if match else 99999
        return sorted(groups, key=get_x_pos)
    except TimeoutException:
        return [] 

def format_header(date_obj, now):
    delta = (date_obj.date() - now.date()).days
    date_str = date_obj.strftime("%A, %d %b")
    suffix = ""
    if delta == 0: suffix = "(Today)"
    elif delta == 1: suffix = "(Tomorrow)"
    elif delta < 7: suffix = "(This Week)"
    else: suffix = "(Upcoming)"
    return f"{date_str} {suffix}"

def update_schedule():
    options = Options()
    options.add_argument("--headless") 
    options.add_argument("-profile")
    options.add_argument(PROFILE_PATH)

    driver = None
    output = {"header": "No Classes Found", "lessons": [], "link": GENERIC_URL}
    
    try:
        driver = webdriver.Firefox(options=options)
        
        # PREVENT HANGING: Set a 30-second timeout for the page to load
        driver.set_page_load_timeout(30)
        
        now = datetime.now()
        
        end_of_school_today = now.replace(hour=15, minute=40)
        
        search_date = now
        check_today = True

        if now > end_of_school_today:
            check_today = False
            search_date = now + timedelta(days=1)

        found_classes = False
        weeks_checked = 0
        
        while not found_classes and weeks_checked < 6:
            current_week_url = get_specific_url(search_date)
            driver.get(current_week_url)
            
            time.sleep(2.5) 
            
            day_columns = get_valid_day_columns(driver)
            
            if day_columns:
                start_weekday_idx = search_date.weekday() 
                
                for day_idx in range(len(day_columns)):
                    monday_of_week = search_date - timedelta(days=search_date.weekday())
                    target_date = monday_of_week + timedelta(days=day_idx)
                    
                    if target_date.date() < search_date.date():
                        continue
                        
                    if target_date.date() == now.date() and not check_today:
                        continue
                        
                    if target_date.weekday() > 4: 
                        continue

                    lessons = extract_lessons_from_group(day_columns[day_idx], target_date)
                    
                    if target_date.date() == now.date():
                        if not lessons: continue
                        real_classes = [l for l in lessons if l['type'] == 'class']
                        if not real_classes: continue
                        if now.timestamp() > real_classes[-1]['end']: continue

                    has_real_classes = any(l.get('type') == 'class' for l in lessons)

                    if lessons and has_real_classes:
                        output["lessons"] = lessons
                        output["header"] = format_header(target_date, now)
                        output["link"] = current_week_url
                        found_classes = True
                        break
            
            if not found_classes:
                days_ahead = 7 - search_date.weekday()
                search_date = search_date + timedelta(days=days_ahead)
                check_today = True 
                weeks_checked += 1

    except Exception as e:
        print(f"Error: {e}")
        output = {"header": "Error", "lessons": [{"type": "class", "time": "Error", "subject": "Check Script", "room": "!", "teacher": str(e), "start": 0, "end": 0, "width": 100, "char_limit": 10}], "link": ""}

    finally:
        if driver: driver.quit()
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, "w") as f:
            json.dump(output, f)

if __name__ == "__main__":
    update_schedule()

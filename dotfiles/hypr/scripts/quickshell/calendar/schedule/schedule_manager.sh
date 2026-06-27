#!/bin/bash

# -----------------------------------------------------------------------------
# CACHING & MIGRATION
# -----------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/../../../caching.sh"
qs_ensure_cache "schedule"

CACHE_DIR="$QS_CACHE_SCHEDULE"
CACHE_FILE="${CACHE_DIR}/schedule.json"
mkdir -p "$CACHE_DIR"

# Generate dynamic epochs so the timeline waves always render relative to current time
NOW=$(date +%s)
START_1=$((NOW - 3600)) # Started an hour ago
END_1=$((NOW + 1800))   # Ends in 30 minutes
START_2=$((NOW + 5400)) # Starts in 1.5 hours
END_2=$((NOW + 9000))   # Ends in 2.5 hours

cat << EOF > "$CACHE_FILE"
{
  "header": "$(date '+%A, %d %b') (Today)",
  "link": "https://calendar.google.com",
  "lessons": [
    {
      "type": "class",
      "time": "09:00-10:30",
      "subject": "Data Structures & Algorithms",
      "room": "CS-Block 402",
      "teacher": "Dr. Sharma",
      "start": $START_1,
      "end": $END_1,
      "width": 120,
      "char_limit": 24,
      "is_compact": false
    },
    {
      "type": "gap",
      "width": 60,
      "desc": "60m",
      "start": $END_1,
      "end": $START_2
    },
    {
      "type": "class",
      "time": "12:00-13:30",
      "subject": "Operating Systems",
      "room": "Lab 9",
      "teacher": "Prof. Verma",
      "start": $START_2,
      "end": $END_2,
      "width": 90,
      "char_limit": 18,
      "is_compact": false
    }
  ]
}
EOF

cat "$CACHE_FILE"
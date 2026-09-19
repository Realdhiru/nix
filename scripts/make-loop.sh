#!/usr/bin/env bash
# make-loop.sh - Creates seamless crossfade video loops with optional start/end trimming
set -euo pipefail

FADE="${FADE:-1.0}"
START=""
END=""
PREVIEW=false

usage() {
    cat << 'EOF'
Usage:
  1. Interactive / Smart Mode (recommended for single files):
     ~/nix/scripts/make-loop.sh video.mp4

  2. Explicit Range Mode:
     ~/nix/scripts/make-loop.sh -s <start_sec> -e <end_sec> [-f <fade_sec>] <video.mp4>
     Example: ~/nix/scripts/make-loop.sh -s 3.5 -e 14.0 -f 1.0 my_recording.mp4

  3. Batch Mode (processes all files with default or specified parameters):
     ~/nix/scripts/make-loop.sh ~/*.mp4

Options:
  -s <sec>   Start time in seconds or HH:MM:SS (trims junk at the start)
  -e <sec>   End time in seconds or HH:MM:SS (trims trailing junk at the end)
  -f <sec>   Crossfade duration in seconds (default: 1.0s)
  -p         Open the generated loop in mpv immediately to verify
  -h         Show this help message
EOF
    exit 0
}

# Parse options
while getopts "s:e:f:ph" opt; do
    case "$opt" in
        s) START="$OPTARG" ;;
        e) END="$OPTARG" ;;
        f) FADE="$OPTARG" ;;
        p) PREVIEW=true ;;
        h) usage ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

if [ "$#" -eq 0 ]; then
    usage
fi

process_file() {
    local input="$1"
    local s_time="$2"
    local e_time="$3"
    local f_dur="$4"

    [ -f "$input" ] || return 0
    if [[ "$input" == *"_loop.mp4"* ]]; then
        return 0
    fi

    local filename dir name output
    filename=$(basename -- "$input")
    dir=$(dirname -- "$input")
    name="${filename%.*}"
    output="${dir}/${name}_loop.mp4"

    # Get total duration
    local total_dur
    total_dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null || echo "0")
    
    if (( $(echo "$total_dur <= 0" | bc -l) )); then
        echo "[!] Error reading video duration for: $filename"
        return 1
    fi

    local s_sec="${s_time:-0}"
    local e_sec="${e_time:-$total_dur}"

    # Calculate segment duration
    local seg_dur
    seg_dur=$(echo "$e_sec - $s_sec" | bc -l)
    
    if (( $(echo "$seg_dur <= $f_dur" | bc -l) )); then
        echo "[!] Trimmed segment ($seg_dur s) is shorter than fade duration ($f_dur s). Skipping $filename."
        return 1
    fi

    local offset
    offset=$(echo "$seg_dur - $f_dur" | bc -l)
    local xfade_offset
    xfade_offset=$(echo "$offset - $f_dur" | bc -l)

    echo "==> Creating loop for: $filename"
    printf "    Segment: [%.2fs -> %.2fs] (Length: %.2fs, Crossfade: %.2fs)\n" "$s_sec" "$e_sec" "$seg_dur" "$f_dur"

    # Precise trim + Tail-to-Head Crossfade + Web-optimized H.264
    ffmpeg -hide_banner -loglevel warning -y \
        -ss "$s_sec" -to "$e_sec" -i "$input" \
        -filter_complex "
            [0:v]split=2[v_main][v_tail];
            [v_main]trim=start=0:end=$offset,setpts=PTS-STARTPTS[v_start];
            [v_tail]trim=start=$offset:end=$seg_dur,setpts=PTS-STARTPTS[v_end];
            [v_start][v_end]xfade=transition=fade:duration=$f_dur:offset=$xfade_offset[v_looped]
        " \
        -map "[v_looped]" \
        -an \
        -c:v libx264 \
        -pix_fmt yuv420p \
        -crf 19 \
        -preset fast \
        -movflags +faststart \
        "$output"

    echo "    ✓ Perfect loop saved -> $output"

    if [ "$PREVIEW" = true ] && command -v mpv >/dev/null 2>&1; then
        echo "    ▶ Playing preview in mpv (infinite loop)... (Press 'q' to close)"
        mpv --loop=inf "$output" >/dev/null 2>&1 || true
    fi
}

# Single file interactive mode if no flags were explicitly passed
if [ "$#" -eq 1 ] && [ -z "$START" ] && [ -z "$END" ] && [ -t 0 ]; then
    target="$1"
    dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$target" 2>/dev/null || echo "0")
    echo "========================================================="
    echo " Video: $(basename "$target")"
    echo " Total Duration: $(printf "%.2f" "$dur") seconds"
    echo "========================================================="
    echo "Tip: Enter the start and end timestamp of the sweet spot."
    echo "     Press ENTER to use the full video."
    echo ""
    read -r -p "Start time (seconds, e.g. 3.5) [default: 0]: " user_s
    read -r -p "End time   (seconds, e.g. 18.0) [default: $(printf "%.2f" "$dur")]: " user_e
    read -r -p "Crossfade  (seconds) [default: 1.0]: " user_f

    user_s="${user_s:-0}"
    user_e="${user_e:-$dur}"
    user_f="${user_f:-1.0}"

    process_file "$target" "$user_s" "$user_e" "$user_f"
    exit 0
fi

# Batch / Flag mode
for file in "$@"; do
    process_file "$file" "$START" "$END" "$FADE"
done

echo ""
echo "==> Done!"

#!/usr/bin/env python3

import subprocess
import json
import re


def run(cmd):
    try:
        return subprocess.check_output(
            cmd,
            shell=True,
            text=True,
            stderr=subprocess.DEVNULL
        )
    except:
        return ""


def parse_volume(line):
    m = re.search(r'\[vol:\s*([0-9.]+)', line)
    if m:
        return int(float(m.group(1)) * 100)
    return 0


def parse_muted(line):
    return "MUTED" in line


def get_default_id(target):
    out = run(f"wpctl inspect {target}")
    m = re.search(r'object.serial = "([0-9]+)"', out)
    if m:
        return m.group(1)
    return ""


default_sink = get_default_id("@DEFAULT_AUDIO_SINK@")
default_source = get_default_id("@DEFAULT_AUDIO_SOURCE@")

status = run("wpctl status")

outputs = []
inputs = []

section = None

for line in status.splitlines():

    if "├─ Sinks:" in line:
        section = "sinks"
        continue

    if "├─ Sources:" in line:
        section = "sources"
        continue

    if "├─ Filters:" in line:
        section = None
        continue

    if section not in ["sinks", "sources"]:
        continue

    m = re.search(r'(\*?)\s*([0-9]+)\.\s+(.*?)\s+\[vol:', line)

    if not m:
        continue

    star = m.group(1)
    node_id = m.group(2)
    desc = m.group(3).strip()

    entry = {
        "id": node_id,
        "name": desc,
        "description": desc,
        "volume": parse_volume(line),
        "mute": parse_muted(line),
        "is_default": (
            node_id == default_sink
            if section == "sinks"
            else node_id == default_source
        ),
        "icon": "audio-card"
    }

    if section == "sinks":
        outputs.append(entry)
    else:
        inputs.append(entry)


result = {
    "outputs": outputs,
    "inputs": inputs,
    "apps": []
}

print(json.dumps(result))
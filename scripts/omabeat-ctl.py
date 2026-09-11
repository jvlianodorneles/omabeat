#!/usr/bin/env python3
"""
omabeat-ctl.py — Backend CLI controller for OmaBeat (Swatch Internet Time) Omarchy Plugin

Usage:
  omabeat-ctl.py get             Output full status JSON
  omabeat-ctl.py beat [--centi]  Output just beat string (e.g. @550 or @550.85)
  omabeat-ctl.py copy [--centi]  Copy beat to Wayland clipboard & send toast
  omabeat-ctl.py to-local <beat> Convert beat (0-1000) to local time
  omabeat-ctl.py to-beat <time>  Convert local time (HH:MM[:SS]) to Swatch beat
  omabeat-ctl.py notify          Send desktop notification with current time stats
  omabeat-ctl.py get-config      Read plugin config JSON
  omabeat-ctl.py set-config <js> Atomically update config JSON
"""

import sys
import os
import stat
import json
import tempfile
import subprocess
from datetime import datetime, timezone, timedelta

CONFIG_DIR = os.path.expanduser("~/.local/state/omarchy/omabeat")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
MAX_CONFIG_BYTES = 65536

DEFAULT_CONFIG = {
    "format": "beats",
    "showCentibeats": False,
    "badgeStyle": "flat",
    "showIcon": True,
    "showPrefix": True,
    "showSuffix": False,
    "centuryChime": False,
    "copyNotification": True
}

def get_beat_stats(now_utc=None):
    if now_utc is None:
        now_utc = datetime.now(timezone.utc)
    
    # BMT is UTC + 1 hour (Central European Time without DST)
    bmt = now_utc + timedelta(hours=1)
    midnight_bmt = bmt.replace(hour=0, minute=0, second=0, microsecond=0)
    diff_sec = (bmt - midnight_bmt).total_seconds()
    
    # 86.4 seconds per beat
    total_beats = diff_sec / 86.4
    int_beats = int(total_beats)
    if int_beats >= 1000:
        int_beats = 0
    centibeats = int((total_beats - int_beats) * 100)
    if centibeats >= 100:
        centibeats = 99

    local_dt = now_utc.astimezone()
    progress_ratio = max(0.0, min(1.0, total_beats / 1000.0))
    progress_pct = round(progress_ratio * 100.0, 1)

    yy = bmt.strftime("%y")
    internet_date = f"@d{bmt.strftime('%d.%m')}.{yy}"

    # Century beat
    next_century = ((int_beats // 100) + 1) * 100
    if next_century >= 1000:
        next_century = 0
    beats_to_next = next_century - int_beats if next_century > int_beats else (1000 - int_beats + next_century)
    minutes_to_next = round(beats_to_next * 86.4 / 60)

    return {
        "beat": round(total_beats, 2),
        "int_beat": int_beats,
        "centibeats": centibeats,
        "formatted": f"@{int_beats:03d}",
        "formatted_centi": f"@{int_beats:03d}.{centibeats:02d}",
        "digits": f"{int_beats:03d}",
        "centi_digits": f"{centibeats:02d}",
        "progress_ratio": progress_ratio,
        "progress_pct": progress_pct,
        "bmt_time": bmt.strftime("%H:%M:%S"),
        "bmt_date": bmt.strftime("%Y-%m-%d"),
        "internet_date": internet_date,
        "utc_time": now_utc.strftime("%H:%M:%S"),
        "local_time": local_dt.strftime("%H:%M:%S"),
        "local_short_time": local_dt.strftime("%H:%M"),
        "local_tz": local_dt.strftime("%Z"),
        "next_century": next_century,
        "beats_to_next_century": beats_to_next,
        "minutes_to_next_century": minutes_to_next
    }

def cmd_get():
    stats = get_beat_stats()
    print(json.dumps(stats, indent=2))

def cmd_beat(centi=False):
    stats = get_beat_stats()
    if centi:
        print(stats["formatted_centi"])
    else:
        print(stats["formatted"])

def cmd_copy(centi=False):
    stats = get_beat_stats()
    text_to_copy = stats["formatted_centi"] if centi else stats["formatted"]
    
    # Copy via wl-copy with stdin to avoid argv leaks and process isolation
    try:
        proc = subprocess.Popen(
            ["wl-copy", "--"],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        try:
            proc.communicate(input=text_to_copy.encode("utf-8"), timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.communicate()
            sys.stderr.write("wl-copy timed out.\n")
            return 1
    except Exception as e:
        sys.stderr.write(f"wl-copy failed: {e}\n")
        return 1

    # Desktop toast notification
    try:
        subprocess.run([
            "notify-send",
            "-a", "OmaBeat",
            "-i", "clock",
            "Swatch Internet Time Copied",
            f"{text_to_copy} (BMT {stats['bmt_time']} • Local {stats['local_time']})"
        ], timeout=3, check=False)
    except Exception:
        pass
    
    print(f"Copied {text_to_copy} to clipboard.")
    return 0

def cmd_to_local(beat_str):
    try:
        b_val = float(beat_str)
        if b_val < 0 or b_val > 1000:
            raise ValueError()
    except ValueError:
        sys.stderr.write(f"Invalid beat value '{beat_str}'. Expected number between 0 and 1000.\n")
        return 1

    now_utc = datetime.now(timezone.utc)
    bmt = now_utc + timedelta(hours=1)
    midnight_bmt = bmt.replace(hour=0, minute=0, second=0, microsecond=0)
    target_bmt = midnight_bmt + timedelta(seconds=(b_val * 86.4))
    target_utc = target_bmt - timedelta(hours=1)
    target_local = target_utc.astimezone()

    res = {
        "beat": b_val,
        "formatted_beat": f"@{int(b_val):03d}",
        "local_time": target_local.strftime("%H:%M:%S"),
        "local_date": target_local.strftime("%Y-%m-%d"),
        "timezone": target_local.strftime("%Z"),
        "bmt_time": target_bmt.strftime("%H:%M:%S")
    }
    print(json.dumps(res, indent=2))
    return 0

def cmd_to_beat(time_str):
    parts = time_str.split(":")
    try:
        h = int(parts[0])
        m = int(parts[1]) if len(parts) > 1 else 0
        s = int(parts[2]) if len(parts) > 2 else 0
        if not (0 <= h <= 23 and 0 <= m <= 59 and 0 <= s <= 59):
            raise ValueError()
    except (ValueError, IndexError):
        sys.stderr.write(f"Invalid time format '{time_str}'. Expected HH:MM or HH:MM:SS.\n")
        return 1

    now_local = datetime.now()
    target_local = now_local.replace(hour=h, minute=m, second=s, microsecond=0)
    target_utc = target_local.astimezone(timezone.utc)
    stats = get_beat_stats(target_utc)

    res = {
        "local_input": f"{h:02d}:{m:02d}:{s:02d}",
        "beat": stats["beat"],
        "formatted": stats["formatted"],
        "formatted_centi": stats["formatted_centi"],
        "bmt_time": stats["bmt_time"]
    }
    print(json.dumps(res, indent=2))
    return 0

def cmd_notify():
    stats = get_beat_stats()
    msg = (
        f"Beats: {stats['formatted_centi']} ({stats['progress_pct']}% of day)\n"
        f"Biel: {stats['bmt_time']} (UTC+1)\n"
        f"Local: {stats['local_time']} ({stats['local_tz']})\n"
        f"Next Century: @{stats['next_century']:03d} in {stats['beats_to_next_century']} beats (~{stats['minutes_to_next_century']}m)"
    )
    try:
        subprocess.run([
            "notify-send",
            "-a", "OmaBeat",
            "-i", "clock",
            f"Swatch Internet Time: {stats['formatted']}",
            msg
        ], timeout=3, check=False)
    except Exception as e:
        sys.stderr.write(f"notify-send failed: {e}\n")
        return 1
    return 0

def ensure_config_dir():
    # Refuse planted symlink on directory
    if os.path.islink(CONFIG_DIR):
        raise OSError(f"Refusing planted symlink at state directory: {CONFIG_DIR}")
    if not os.path.exists(CONFIG_DIR):
        os.makedirs(CONFIG_DIR, mode=0o700, exist_ok=True)
    try:
        os.chmod(CONFIG_DIR, 0o700)
    except OSError:
        pass

def cmd_get_config():
    ensure_config_dir()
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
    try:
        fd = os.open(CONFIG_FILE, flags)
    except (FileNotFoundError, OSError):
        print(json.dumps(DEFAULT_CONFIG, indent=2))
        return 0

    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_size > MAX_CONFIG_BYTES:
            print(json.dumps(DEFAULT_CONFIG, indent=2))
            return 0
        with os.fdopen(fd, "r", encoding="utf-8") as f:
            data = json.load(f)
            merged = {**DEFAULT_CONFIG, **data}
            print(json.dumps(merged, indent=2))
            return 0
    except Exception:
        print(json.dumps(DEFAULT_CONFIG, indent=2))
        return 0

def cmd_set_config(json_str):
    ensure_config_dir()
    try:
        data = json.loads(json_str)
        if not isinstance(data, dict):
            raise ValueError("Configuration payload must be a JSON object.")
    except Exception as e:
        sys.stderr.write(f"Invalid JSON payload: {e}\n")
        return 1

    merged = {**DEFAULT_CONFIG, **data}

    # Atomic write to config.json using mkstemp in destination directory
    fd, tmp_path = tempfile.mkstemp(dir=CONFIG_DIR, prefix=".config.tmp.")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(merged, f, indent=2)
            f.flush()
            os.fsync(fd)
        os.replace(tmp_path, CONFIG_FILE)
        
        # Sync directory to ensure durability
        dir_fd = os.open(CONFIG_DIR, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_CLOEXEC", 0))
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
            
        print(json.dumps(merged, indent=2))
        return 0
    except Exception as e:
        if os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
        sys.stderr.write(f"Failed to write config: {e}\n")
        return 1

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print(__doc__.strip())
        return 0

    cmd = sys.argv[1]
    if cmd == "get" or cmd == "json":
        return cmd_get()
    elif cmd == "beat":
        centi = "--centi" in sys.argv
        return cmd_beat(centi)
    elif cmd == "copy":
        centi = "--centi" in sys.argv
        return cmd_copy(centi)
    elif cmd == "to-local":
        if len(sys.argv) < 3:
            sys.stderr.write("Usage: omabeat-ctl.py to-local <beat>\n")
            return 1
        return cmd_to_local(sys.argv[2])
    elif cmd == "to-beat":
        if len(sys.argv) < 3:
            sys.stderr.write("Usage: omabeat-ctl.py to-beat <HH:MM[:SS]>\n")
            return 1
        return cmd_to_beat(sys.argv[2])
    elif cmd == "notify":
        return cmd_notify()
    elif cmd == "get-config":
        return cmd_get_config()
    elif cmd == "set-config":
        if len(sys.argv) < 3:
            sys.stderr.write("Usage: omabeat-ctl.py set-config <json_payload>\n")
            return 1
        return cmd_set_config(sys.argv[2])
    else:
        sys.stderr.write(f"Unknown command '{cmd}'. Run with --help for usage.\n")
        return 1

if __name__ == "__main__":
    sys.exit(main() or 0)

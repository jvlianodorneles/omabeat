# ⏱ OmaBeat — Swatch Internet Time (.beat) for Omarchy

> **Universal decimal time for your Linux desktop.** Zero timezones, zero daylight saving time, 1000 beats per day.

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-blue.svg)](https://github.com/omacom/omarchy)
[![Quickshell](https://img.shields.io/badge/quickshell-v0.3+-purple.svg)](https://github.com/outfoxxed/quickshell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**OmaBeat** brings **Swatch Internet Time** (Biel Mean Time / `.beat`) to the Omarchy status bar and Wayland desktop. Conceived in 1998 by the Swatch Corporation and Nicholas Negroponte (MIT Media Lab), Internet Time eliminates geographic time zones and daylight saving time changes, replacing them with a single global solar day divided into **1000 .beats**.

---

## 🌐 How Swatch Internet Time Works

- **Standard Meridian:** Biel Mean Time (**BMT**), fixed at **UTC+1** (Central European Time) year-round with **no Daylight Saving Time**.
- **The .beat:** The 24-hour solar day is divided into **1,000 `.beats`**.
  - **1 .beat** = 86.4 seconds (1 min 26.4 sec = 86,400 ms).
  - **1 centibeat** (sub-beat) = 0.864 seconds (864 ms).
- **Notation:** Represented with an `@` prefix followed by 3 digits (e.g. `@000` to `@999`).
- **Universal Synchronization:** Regardless of where you are on Earth, Internet Time is identical for everyone at any given moment. When it is `@500` in Tokyo, it is `@500` in London, São Paulo, and New York.

### Cardinal Milestones

| Beat | Biel Mean Time (UTC+1) | UTC | Solar Meaning |
| :--- | :--- | :--- | :--- |
| **`@000`** | 00:00:00 | 23:00:00 (prev) | Start of Internet Day / Swiss Midnight |
| **`@250`** | 06:00:00 | 05:00:00 | Morning / First Quadrant |
| **`@500`** | 12:00:00 | 11:00:00 | Solar Noon in Biel |
| **`@750`** | 18:00:00 | 17:00:00 | Evening / Third Quadrant |
| **`@1000`** | 24:00:00 | 23:00:00 | Day rollover |

---

## ✨ Features

### 1. Status Bar Widget (`BarWidget.qml`)
- **Multiple Display Formats:**
  - `@550` (Standard 3-digit zero-padded beats)
  - `@550.85` (Live centibeats ticking every 0.864s)
  - `@550 .beats` (Full unit suffix)
  - `@550 (55.0%)` (With day completion percentage)
  - `@550 (09:18)` (Dual time: Beats + Local time)
- **Badge Styles:**
  - `flat`: Clean, transparent status bar typography.
  - `pill`: Rounded modern capsule container.
  - `progress`: Interactive background fill tracking the 0–1000 beat progress throughout the solar day.
- **Intuitive Mouse Gestures:**
  - **Left-Click:** Open interactive popup panel and converter.
  - **Middle-Click:** Toggle centibeats precision (`@550` ⟷ `@550.85`).
  - **Right-Click:** Instantly copy current beat (`@550`) to clipboard.
  - **Scroll Wheel:** Cycle through display formats.
- **Rich Multi-Line Tooltip:** Displays current beat, centibeat, BMT time, UTC, Local time, day progress ratio, beats remaining today, and next century milestone.

### 2. Interactive Popup Panel (`Panel.qml`)
- **Hero Beat Readout:** Large, retro-cyberpunk typographic display of the live beat with ticking sub-beats.
- **Day Beat Progress Bar:** Visual bar indicating elapsed beats across the 1000-beat solar day.
- **Tri-Time Reference:** Side-by-side synchronized cards comparing **BMT (Biel UTC+1)**, **UTC**, and **Local Time**.
- **Two-Way Beat ⟷ Local Time Converter:**
  - Interactive slider stepping through beats to reveal exact local time.
  - Quick-preset milestone buttons (`@000`, `@250`, `@500`, `@750`).
- **One-Click Share/Copy Buttons:**
  - Copy `@550`
  - Copy `@550.85`
  - Copy formatted timestamp with BMT context (`@550 (@d11.09.26 • 13:18 BMT)`)
- **Century Beat Milestone Tracker:** Live countdown to the next 100-beat milestone (`@600 in 46 beats (~66 min)`).
- **Century Chime:** Optional desktop notification when reaching century beats (`@100`, `@200`, etc.).
- **Wayland Keyboard Navigation:** Fully operable via `KeyboardPanel` and `PanelKeyCatcher`:
  - `c` — Copy current beat
  - `p` — Toggle centibeat precision
  - `1`, `2`, `3`, `4` — Jump to milestones (`@000`, `@250`, `@500`, `@750`)
  - `r` — Force refresh
  - `Esc` — Close panel

### 3. Command Line Interface (`bin/omabeat`)
A standalone CLI tool is included for scripts, terminal prompts, and Hyprland keybindings:

```bash
# Print current beat (@550)
omabeat beat

# Print with live centibeats (@550.85)
omabeat beat --centi

# Get full JSON status
omabeat get

# Copy current beat to Wayland clipboard with desktop toast
omabeat copy

# Convert a beat to local time
omabeat to-local 750

# Convert local time to Swatch beats
omabeat to-beat 14:30

# Send desktop notification with current time stats
omabeat notify
```

---

## 🚀 Installation

### Automated Install
Clone or copy into your workspace and run:

```bash
cd /home/dorneles/Projects/omabeat
./install.sh
```

Then reload your Omarchy shell:
```bash
omarchy-restart-shell
```

### Manual Install
Link the plugin to your Omarchy plugins directory:
```bash
ln -s /home/dorneles/Projects/omabeat ~/.config/omarchy/plugins/dorneles.omabeat
ln -s /home/dorneles/Projects/omabeat/bin/omabeat ~/.local/bin/omabeat
```

Validate the plugin anytime with:
```bash
omarchy plugin validate /home/dorneles/Projects/omabeat
```

---

## ⚙️ Configuration Schema

You can customize OmaBeat via `~/.config/omarchy/shell.json` or through the Omarchy Plugin Settings GUI:

```json
{
  "id": "dorneles.omabeat",
  "format": "beats",
  "showCentibeats": false,
  "badgeStyle": "flat",
  "showIcon": true,
  "showPrefix": true,
  "showSuffix": false,
  "centuryChime": false,
  "copyNotification": true
}
```

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `format` | enum | `"beats"` | Options: `"beats"`, `"centibeats"`, `"with_unit"`, `"percentage"`, `"dual_local"` |
| `badgeStyle` | enum | `"flat"` | Options: `"flat"`, `"pill"`, `"progress"` |
| `showCentibeats`| bool | `false` | Enable live 2-decimal ticking centibeats on bar |
| `showIcon` | bool | `true` | Show `@` dial icon before text |
| `showPrefix` | bool | `true` | Show `@` prefix before number |
| `showSuffix` | bool | `false` | Show `.beats` suffix |
| `centuryChime` | bool | `false` | Desktop notification every 100 beats |
| `copyNotification` | bool | `true` | Toast on clipboard copy |

---

## 💡 Suggested Features & Future Roadmap

Here are recommended ideas and enhancements for future releases of OmaBeat:

1. **Beat Alarms & Pomodoro (`Beatodoro`)**:
   - Set timers measured in beats (e.g. standard Pomodoro work session = 17.36 beats / 25 minutes; short break = 3.47 beats / 5 minutes).
   - "Remind me at @650" alarm feature with desktop sound/chime.
2. **Global Meeting Planner / Link Generator**:
   - Click to create a `meet.google.com` or calendar invite labeled "Sync at @750".
   - Generate shareable Markdown/Slack links: `Let's sync at @750 (14:00 BRT / 17:00 UTC)`.
3. **Retro 1998 Swatch Watch Skin / Vintage Dial View**:
   - Optional retro Y2K digital LCD skin or round analog watch face rendering inside the popup panel.
4. **Hyprland Keybinding Integration**:
   - Global hotkey (`SUPER + B`) to summon the OmaBeat panel or copy `@beat` straight into active window.
5. **Star Citizen / Gaming & IRC Timestamp Integration**:
   - Output Swatch Internet Time directly to Twitch/Discord/IRC bots or game chat overlays.

---

## 🛡 Security & Craftsmanship

OmaBeat is designed and audited in compliance with the **Omarchy Plugin Security Specification**:
- Strict `textFormat: Text.PlainText` on every QML Text sink to prevent rich text/HTML injection.
- Zero raw shell interpolation; all child executions use argv arrays.
- Bound I/O buffers with no unconstrained collectors.
- Safe atomic file operations with mode `0600` in restricted state directories (`0700`).
- Strict validation via `omarchy plugin validate`.

---

## 📄 License

MIT License © 2026 Dorneles.

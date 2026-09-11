#!/usr/bin/env bash
# ==============================================================================
# OmaBeat — Installer Script for Omarchy
# Swatch Internet Time (.beat) Bar Widget & Panel
# ==============================================================================

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
STATE_DIR="${HOME}/.local/state/omarchy/omabeat"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"
OMARCHY_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/dorneles.omabeat"

echo "⏱  Installing OmaBeat (Swatch Internet Time)..."

# 1. Install CLI Tool
mkdir -p "${BIN_DIR}"
install -Dm755 "${SOURCE_DIR}/scripts/omabeat-ctl.py" "${BIN_DIR}/omabeat"
echo "✓ Installed CLI tool to ${BIN_DIR}/omabeat"

# 2. Install Omarchy Quickshell Plugin
mkdir -p "${OMARCHY_PLUGIN_DIR}/assets"
mkdir -p "${OMARCHY_PLUGIN_DIR}/scripts"
mkdir -p "${STATE_DIR}"
chmod 700 "${STATE_DIR}" 2>/dev/null || true

cp -f "${SOURCE_DIR}/manifest.json" \
      "${SOURCE_DIR}/BarWidget.qml" \
      "${SOURCE_DIR}/Panel.qml" \
      "${SOURCE_DIR}/BeatModel.js" \
      "${OMARCHY_PLUGIN_DIR}/"

cp -rf "${SOURCE_DIR}/assets" "${OMARCHY_PLUGIN_DIR}/"
cp -rf "${SOURCE_DIR}/scripts" "${OMARCHY_PLUGIN_DIR}/"

echo "✓ Installed Omarchy Plugin to ${OMARCHY_PLUGIN_DIR}"

# 3. Register in Omarchy shell.json if not present
if [ -f "${SHELL_CONFIG}" ]; then
  OMABEAT_CONFIG_PATH="${SHELL_CONFIG}" python3 -c "
import json, os
config_path = os.environ.get('OMABEAT_CONFIG_PATH')
try:
    with open(config_path, 'r') as f:
        data = json.load(f)

    bar_layout = data.setdefault('bar', {}).setdefault('layout', {})
    right_list = bar_layout.setdefault('right', [])
    ids = [item.get('id') if isinstance(item, dict) else item for item in right_list]
    if 'dorneles.omabeat' not in ids:
        right_list.append({'id': 'dorneles.omabeat'})
        print('✓ Registered dorneles.omabeat in Omarchy status bar layout')

    with open(config_path, 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    print('Note: Could not automatically update shell.json:', e)
"
fi

# 4. Trigger reload
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate "${OMARCHY_PLUGIN_DIR}" >/dev/null 2>&1 || true
fi

if command -v omarchy-restart-shell >/dev/null 2>&1; then
  echo "💡 Tip: Run 'omarchy-restart-shell' to refresh your bar now."
fi

echo "✨ OmaBeat installed successfully! Check your status bar for @beat time."

#!/usr/bin/env bash
# ==============================================================================
# OmaBeat — Uninstaller Script for Omarchy
# ==============================================================================

set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"
OMARCHY_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/dorneles.omabeat"

echo "🗑️  Uninstalling OmaBeat..."

# 1. Remove CLI binary
if [ -f "${BIN_DIR}/omabeat" ]; then
  rm -f "${BIN_DIR}/omabeat"
  echo "✓ Removed ${BIN_DIR}/omabeat"
fi

# 2. Remove Plugin Directory
if [ -d "${OMARCHY_PLUGIN_DIR}" ]; then
  rm -rf "${OMARCHY_PLUGIN_DIR}"
  echo "✓ Removed plugin directory ${OMARCHY_PLUGIN_DIR}"
fi

# 3. Unregister from shell.json
if [ -f "${SHELL_CONFIG}" ]; then
  OMABEAT_CONFIG_PATH="${SHELL_CONFIG}" python3 -c "
import json, os
config_path = os.environ.get('OMABEAT_CONFIG_PATH')
try:
    with open(config_path, 'r') as f:
        data = json.load(f)

    bar_layout = data.get('bar', {}).get('layout', {})
    for sec in ['left', 'center', 'right']:
        if sec in bar_layout and isinstance(bar_layout[sec], list):
            bar_layout[sec] = [item for item in bar_layout[sec] if (item.get('id') if isinstance(item, dict) else item) != 'dorneles.omabeat']

    if 'plugins' in data and isinstance(data['plugins'], list):
        data['plugins'] = [item for item in data['plugins'] if (item.get('id') if isinstance(item, dict) else item) != 'dorneles.omabeat']

    with open(config_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('✓ Unregistered dorneles.omabeat from shell.json')
except Exception as e:
    print('Note: Could not update shell.json:', e)
"
fi

if command -v omarchy-restart-shell >/dev/null 2>&1; then
  echo "💡 Tip: Run 'omarchy-restart-shell' to reload your bar."
fi

echo "✨ OmaBeat uninstalled successfully."

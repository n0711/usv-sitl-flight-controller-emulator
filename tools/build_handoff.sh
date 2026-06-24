#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_DIR}/build"
HANDOFF_DIR="${BUILD_DIR}/ai_team_handoff"
ZIP_PATH="${BUILD_DIR}/usv-sitl-ai-team-handoff.zip"
RUNTIME_ARCHIVE="${BUILD_DIR}/release/usv-sitl-interface-runtime.tar.gz"
DEFAULT_SAMPLE_LOG=""
SAMPLE_LOG="${SAMPLE_LOG:-$DEFAULT_SAMPLE_LOG}"

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: '${command_name}' was not found on PATH." >&2
    exit 127
  fi
}

require_command zip
require_command sha256sum

"${SCRIPT_DIR}/package_release.sh"

rm -rf "$HANDOFF_DIR" "$ZIP_PATH"
mkdir -p "$HANDOFF_DIR/sample_logs"

cp "$RUNTIME_ARCHIVE" "$HANDOFF_DIR/"
cp "$REPO_DIR/TEST_INSTRUCTIONS.md" "$HANDOFF_DIR/TEST_INSTRUCTIONS.md"
cp "$REPO_DIR/tools/setup_ubuntu.sh" "$HANDOFF_DIR/setup_ubuntu.sh"
chmod +x "$HANDOFF_DIR/setup_ubuntu.sh"

if [[ -f "$SAMPLE_LOG" ]]; then
  cp "$SAMPLE_LOG" "$HANDOFF_DIR/sample_logs/"
else
  cat >"$HANDOFF_DIR/sample_logs/PUT_SAMPLE_BIN_LOG_HERE.txt" <<'EOF'
No sample log was found while building this handoff.
Put a .BIN/.bin ArduPilot log in this folder before testing, or copy one into
the runtime package logs/ folder after extraction.
EOF
fi

(
  cd "$HANDOFF_DIR"
  find . -type f ! -name SHA256SUMS.txt -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
)

(
  cd "$HANDOFF_DIR"
  zip -qr "$ZIP_PATH" .
)

echo "Built handoff zip:"
echo "$ZIP_PATH"

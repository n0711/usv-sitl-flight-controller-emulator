#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${1:-}"
HEADING="${2:-0}"

if [[ -d "$APP_DIR/.venv/bin" ]]; then
  export PATH="$APP_DIR/.venv/bin:$PATH"
fi

if [[ "$LOG_FILE" == "--help" || "$LOG_FILE" == "-h" ]]; then
  cat <<'EOF'
Usage:
  ./bin/start_from_log
  ./bin/start_from_log logs/example.BIN
  ./bin/start_from_log logs/example.BIN 90
  ./bin/start_from_log --print-location logs/example.BIN

When no log path is passed, exactly one .BIN/.bin file must exist in logs/.
The optional heading argument is in degrees.
EOF
  exit 0
fi

PRINT_ONLY=0
if [[ "$LOG_FILE" == "--print-location" ]]; then
  PRINT_ONLY=1
  LOG_FILE="${2:-}"
  HEADING="${3:-0}"
fi

if [[ -x "$APP_DIR/bin/run_sim.sh" ]]; then
  RUN_SIM="$APP_DIR/bin/run_sim.sh"
else
  RUN_SIM="$APP_DIR/run_sim.sh"
fi

if [[ -z "$LOG_FILE" ]]; then
  mapfile -t logs < <(find "$APP_DIR/logs" -maxdepth 1 -type f \( -name '*.BIN' -o -name '*.bin' \) 2>/dev/null | sort)
  if [[ "${#logs[@]}" -eq 0 ]]; then
    echo "ERROR: No .BIN log was found in ${APP_DIR}/logs." >&2
    echo "Put a log there or pass the log path: ./bin/start_from_log path/to/log.BIN" >&2
    exit 1
  fi
  if [[ "${#logs[@]}" -gt 1 ]]; then
    echo "ERROR: More than one .BIN log was found in ${APP_DIR}/logs." >&2
    echo "Pass the one to use explicitly:" >&2
    printf '  %s\n' "${logs[@]}" >&2
    exit 1
  fi
  LOG_FILE="${logs[0]}"
fi

if [[ ! -f "$LOG_FILE" ]]; then
  if [[ "$LOG_FILE" != /* && -f "$APP_DIR/$LOG_FILE" ]]; then
    LOG_FILE="$APP_DIR/$LOG_FILE"
  else
    echo "ERROR: Log file not found: ${LOG_FILE}" >&2
    exit 1
  fi
fi

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: '${command_name}' was not found on PATH." >&2
    exit 127
  fi
}

require_command mavlogdump.py

set +o pipefail
first_gps="$(mavlogdump.py --types GPS "$LOG_FILE" 2>/dev/null | awk '/GPS \{/{ print; exit }')"
set -o pipefail

if [[ -z "$first_gps" ]]; then
  echo "ERROR: No GPS messages were found in ${LOG_FILE}." >&2
  exit 1
fi

location="$(
  sed -n 's/.*Lat : \([^,]*\), Lng : \([^,]*\), Alt : \([^,]*\),.*/\1,\2,\3/p' <<<"$first_gps"
)"

if [[ -z "$location" ]]; then
  echo "ERROR: Could not parse GPS Lat/Lng/Alt from ${LOG_FILE}." >&2
  echo "First GPS line was:" >&2
  echo "$first_gps" >&2
  exit 1
fi

echo "Using log: ${LOG_FILE}"
echo "Starting SITL at: ${location},${HEADING}"

if [[ "$PRINT_ONLY" -eq 1 ]]; then
  echo "SITL_LOCATION=\"${location},${HEADING}\""
  exit 0
fi

exec env SITL_LOCATION="${location},${HEADING}" "$RUN_SIM"

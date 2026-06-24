#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/mav.parm" ]]; then
  DEFAULT_PARAM_FILE="${SCRIPT_DIR}/mav.parm"
else
  DEFAULT_PARAM_FILE="$(cd -- "${SCRIPT_DIR}/.." && pwd)/mav.parm"
fi
PARAM_FILE="${PARAM_FILE:-$DEFAULT_PARAM_FILE}"

APP_DIR="$(cd -- "${SCRIPT_DIR}" && pwd)"
if [[ ! -f "${APP_DIR}/mav.parm" ]]; then
  APP_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
fi
if [[ -d "$APP_DIR/.venv/bin" ]]; then
  export PATH="$APP_DIR/.venv/bin:$PATH"
fi

VEHICLE="${VEHICLE:-Rover}"
FRAME="${FRAME:-motorboat}"
MAVLINK2REST_BIN="${MAVLINK2REST_BIN:-mavlink2rest}"
SERVER_BIND_ADDR="${SERVER_BIND_ADDR:-0.0.0.0:8088}"
MAVLINK_JSON_OUT="${MAVLINK_JSON_OUT:-udp:127.0.0.1:14551}"
MAVLINK2REST_OUT="${MAVLINK2REST_OUT:-udp:127.0.0.1:14552}"
MAVLINK2REST_CONNECT="${MAVLINK2REST_CONNECT:-udpin:127.0.0.1:14552}"
SITL_RITW_TERMINAL="${SITL_RITW_TERMINAL:-bash}"
SITL_LOCATION="${SITL_LOCATION:-}"
export SITL_RITW_TERMINAL

SIM_PID=""
REST_PID=""

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "ERROR: '${command_name}' was not found on PATH." >&2
    exit 127
  fi
}

kill_tree() {
  local pid="$1"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" >/dev/null 2>&1; then
    return
  fi
  kill -TERM -- "-${pid}" >/dev/null 2>&1 || kill -TERM "$pid" >/dev/null 2>&1 || true
  sleep 2
  kill -KILL -- "-${pid}" >/dev/null 2>&1 || kill -KILL "$pid" >/dev/null 2>&1 || true
}

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM

  echo
  echo "Stopping MAVLink2REST and SITL processes..."
  kill_tree "$REST_PID"
  kill_tree "$SIM_PID"

  exit "$exit_code"
}

trap cleanup EXIT INT TERM

if [[ ! -f "$PARAM_FILE" ]]; then
  echo "ERROR: Parameter file not found: ${PARAM_FILE}" >&2
  exit 1
fi

require_command sim_vehicle.py
require_command "$MAVLINK2REST_BIN"
require_command setsid

echo "Starting MAVLink2REST web server on port ${SERVER_BIND_ADDR}..."
setsid "$MAVLINK2REST_BIN" \
  --server "$SERVER_BIND_ADDR" \
  --connect "$MAVLINK2REST_CONNECT" &
REST_PID=$!

echo "Starting ArduPilot SITL (${VEHICLE}/${FRAME}) with ${PARAM_FILE}..."
SIM_ARGS=(
  -v "$VEHICLE" \
  -f "$FRAME" \
  --wipe-eeprom \
  --add-param-file="$PARAM_FILE" \
  --no-extra-ports \
  --out="$MAVLINK_JSON_OUT" \
  --out="$MAVLINK2REST_OUT" \
  --mavproxy-args="--non-interactive --mavversion=2.0"
)

if [[ -n "$SITL_LOCATION" ]]; then
  SIM_ARGS+=(--custom-location "$SITL_LOCATION")
fi

setsid sim_vehicle.py "${SIM_ARGS[@]}" &
SIM_PID=$!

wait "$SIM_PID"

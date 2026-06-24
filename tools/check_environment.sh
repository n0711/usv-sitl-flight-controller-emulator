#!/usr/bin/env bash
set -Eeuo pipefail

missing=0
APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if [[ -x "$APP_DIR/.venv/bin/python" ]]; then
  export PATH="$APP_DIR/.venv/bin:$PATH"
  PYTHON_BIN="$APP_DIR/.venv/bin/python"
fi

check_command() {
  local command_name="$1"
  if command_path="$(command -v "$command_name" 2>/dev/null)"; then
    printf 'OK   %-16s %s\n' "$command_name" "$command_path"
  else
    printf 'MISS %-16s not found on PATH\n' "$command_name"
    missing=1
  fi
}

echo "Checking required runtime commands..."
if command_path="$(command -v "$PYTHON_BIN" 2>/dev/null)"; then
  printf 'OK   %-16s %s\n' python3 "$command_path"
else
  printf 'MISS %-16s not found on PATH\n' python3
  missing=1
fi
check_command sim_vehicle.py
check_command mavproxy.py
check_command mavlogdump.py
check_command mavlink2rest
check_command setsid
check_command gcc
check_command g++
check_command make

echo
echo "Checking Python imports..."
if "$PYTHON_BIN" - <<'PY'
checks = [
    ("dronecan", "dronecan"),
    ("empy", "em"),
    ("geocoder", "geocoder"),
    ("intelhex", "intelhex"),
    ("junitparser", "junitparser"),
    ("lxml", "lxml.etree"),
    ("MAVProxy", "MAVProxy"),
    ("numpy", "numpy"),
    ("pexpect", "pexpect"),
    ("psutil", "psutil"),
    ("ptyprocess", "ptyprocess"),
    ("pymavlink", "pymavlink.mavutil"),
    ("pyparsing", "pyparsing"),
    ("pyserial", "serial"),
    ("PyYAML", "yaml"),
    ("tabulate", "tabulate"),
    ("wsproto", "wsproto"),
]

import importlib
import sys

failed = []
for label, module_name in checks:
    try:
        module = importlib.import_module(module_name)
        if label == "empy" and not getattr(module, "RAW_OPT", None):
            raise RuntimeError("wrong empy version; install empy==3.3.4")
        print(f"OK   {label} import")
    except Exception as exc:
        print(f"MISS {label} import failed: {exc}")
        failed.append(label)

if failed:
    sys.exit(1)
PY
then
  :
else
  missing=1
fi

if [[ "$missing" -eq 0 ]]; then
  echo
  echo "Environment check passed."
else
  echo
  echo "Environment check failed. Install the missing tools before running SITL."
fi

exit "$missing"

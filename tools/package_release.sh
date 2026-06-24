#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_DIR}/build/release"
PACKAGE_NAME="usv-sitl-interface-runtime"
PACKAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}"
ARCHIVE_PATH="${BUILD_DIR}/${PACKAGE_NAME}.tar.gz"

rm -rf "$PACKAGE_DIR" "$ARCHIVE_PATH"
mkdir -p "$PACKAGE_DIR/bin" "$PACKAGE_DIR/lib" "$PACKAGE_DIR/docs"
mkdir -p "$PACKAGE_DIR/logs"

cp "$REPO_DIR/run_sim.sh" "$PACKAGE_DIR/bin/run_sim.sh"
cp "$REPO_DIR/tools/check_environment.sh" "$PACKAGE_DIR/bin/check_environment"
cp "$REPO_DIR/tools/start_from_log.sh" "$PACKAGE_DIR/bin/start_from_log"
cp "$REPO_DIR/tools/setup_ubuntu.sh" "$PACKAGE_DIR/bin/setup_ubuntu"
cp "$REPO_DIR/tools/command_test.sh" "$PACKAGE_DIR/bin/command_test"
cp "$REPO_DIR/mav.parm" "$PACKAGE_DIR/mav.parm"
cp "$REPO_DIR/README.md" "$PACKAGE_DIR/README.md"
cp "$REPO_DIR/README.md" "$PACKAGE_DIR/USAGE.md"
cp "$REPO_DIR/requirements.txt" "$PACKAGE_DIR/requirements.txt"

cat >"$PACKAGE_DIR/logs/PUT_BIN_LOGS_HERE.txt" <<'EOF'
Put one .BIN/.bin ArduPilot log in this folder, then run:

  ./bin/start_from_log

If this folder contains more than one log, pass the log explicitly:

  ./bin/start_from_log "logs/example.BIN"
EOF

if [[ -d "$REPO_DIR/docs" ]]; then
  cp -R "$REPO_DIR/docs/." "$PACKAGE_DIR/docs/"
fi

python3 - <<PY
import py_compile

py_compile.compile(
    "${REPO_DIR}/src/mavlink_to_json.py",
    cfile="${PACKAGE_DIR}/lib/mavlink_to_json.pyc",
    doraise=True,
)
py_compile.compile(
    "${REPO_DIR}/src/json_receiver.py",
    cfile="${PACKAGE_DIR}/lib/json_receiver.pyc",
    doraise=True,
)
PY

cat >"$PACKAGE_DIR/bin/mavlink_to_json" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
if [[ -x "$APP_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$APP_DIR/.venv/bin/python"
fi
exec "$PYTHON_BIN" "$APP_DIR/lib/mavlink_to_json.pyc" "$@"
EOF

cat >"$PACKAGE_DIR/bin/json_receiver" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
if [[ -x "$APP_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$APP_DIR/.venv/bin/python"
fi
exec "$PYTHON_BIN" "$APP_DIR/lib/json_receiver.pyc" "$@"
EOF

chmod +x "$PACKAGE_DIR/bin/run_sim.sh" \
  "$PACKAGE_DIR/bin/check_environment" \
  "$PACKAGE_DIR/bin/setup_ubuntu" \
  "$PACKAGE_DIR/bin/command_test" \
  "$PACKAGE_DIR/bin/start_from_log" \
  "$PACKAGE_DIR/bin/mavlink_to_json" \
  "$PACKAGE_DIR/bin/json_receiver"

tar -C "$BUILD_DIR" -czf "$ARCHIVE_PATH" "$PACKAGE_NAME"

echo "Built runtime package:"
echo "$ARCHIVE_PATH"

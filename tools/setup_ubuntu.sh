#!/usr/bin/env bash
set -Eeuo pipefail

WORK_DIR="${WORK_DIR:-$HOME/usv_sitl_test}"
RUNTIME_DIR="${RUNTIME_DIR:-$WORK_DIR/usv-sitl-interface-runtime}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-$HOME/Downloads}"
ARDUPILOT_DIR="${ARDUPILOT_DIR:-$HOME/ardupilot}"
MAVLINK2REST_VERSION="${MAVLINK2REST_VERSION:-1.0.2}"
ARDUPILOT_PYTHON_PKGS=(
  dronecan
  empy==3.3.4
  flake8
  geocoder
  intelhex
  junitparser
  lxml
  MAVProxy
  numpy
  pexpect
  psutil
  ptyprocess
  pymavlink
  pyparsing
  pyserial
  PyYAML
  tabulate
  wsproto
)

msg() {
  printf '\n==> %s\n' "$*"
}

need_sudo() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

find_first_file() {
  local name="$1"
  shift
  local dir
  for dir in "$@"; do
    if [[ -f "$dir/$name" ]]; then
      printf '%s\n' "$dir/$name"
      return 0
    fi
  done
  return 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../requirements.txt" ]]; then
  RUNTIME_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
  WORK_DIR="$(dirname "$RUNTIME_DIR")"
fi

msg "Installing basic Ubuntu tools"
need_sudo apt update
need_sudo apt install -y \
  git curl ca-certificates zip unzip tar build-essential \
  python3 python3-pip python3-venv python3-dev

mkdir -p "$WORK_DIR"

msg "Looking for the USV SITL package"
handoff_zip="$(find_first_file usv-sitl-ai-team-handoff.zip "$PWD" "$DOWNLOADS_DIR" "$WORK_DIR" || true)"
runtime_tgz="$(find_first_file usv-sitl-interface-runtime.tar.gz "$PWD" "$DOWNLOADS_DIR" "$WORK_DIR" || true)"

if [[ -n "$handoff_zip" ]]; then
  unzip -o "$handoff_zip" -d "$WORK_DIR"
  runtime_tgz="$(find_first_file usv-sitl-interface-runtime.tar.gz "$WORK_DIR" "$PWD" "$DOWNLOADS_DIR" || true)"
fi

if [[ -n "$runtime_tgz" ]]; then
  msg "Extracting or refreshing the USV SITL runtime"
  tar \
    --exclude='usv-sitl-interface-runtime/.venv' \
    --exclude='usv-sitl-interface-runtime/logs' \
    -xzf "$runtime_tgz" -C "$WORK_DIR"
  mkdir -p "$RUNTIME_DIR/logs"
elif [[ ! -d "$RUNTIME_DIR" ]]; then
  if [[ -z "$runtime_tgz" ]]; then
    echo "ERROR: Could not find usv-sitl-interface-runtime.tar.gz." >&2
    echo "Put usv-sitl-ai-team-handoff.zip or usv-sitl-interface-runtime.tar.gz in Downloads, then run this again." >&2
    exit 1
  fi
fi

msg "Installing ArduPilot SITL"
if [[ ! -d "$ARDUPILOT_DIR/.git" ]]; then
  git clone https://github.com/ArduPilot/ardupilot.git "$ARDUPILOT_DIR"
fi
git -C "$ARDUPILOT_DIR" submodule update --init --recursive
"$ARDUPILOT_DIR/Tools/environment_install/install-prereqs-ubuntu.sh" -y

if ! grep -Fq 'ardupilot/Tools/autotest' "$HOME/.bashrc" 2>/dev/null; then
  printf '\nexport PATH="$HOME/ardupilot/Tools/autotest:$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
fi
export PATH="$HOME/ardupilot/Tools/autotest:$HOME/.local/bin:$PATH"

msg "Installing MAVLink2REST"
arch="$(uname -m)"
case "$arch" in
  x86_64)
    mavlink2rest_asset="mavlink2rest-x86_64-unknown-linux-musl"
    ;;
  aarch64|arm64)
    mavlink2rest_asset="mavlink2rest-aarch64-unknown-linux-musl"
    ;;
  *)
    echo "ERROR: Unsupported CPU type for automatic mavlink2rest install: $arch" >&2
    echo "Download the correct mavlink2rest binary manually, then put it on PATH." >&2
    exit 1
    ;;
esac

need_sudo curl -L \
  "https://github.com/mavlink/mavlink2rest/releases/download/${MAVLINK2REST_VERSION}/${mavlink2rest_asset}" \
  -o /usr/local/bin/mavlink2rest
need_sudo chmod +x /usr/local/bin/mavlink2rest

msg "Installing Python requirements"
cd "$RUNTIME_DIR"
python3 -m venv "$RUNTIME_DIR/.venv"
"$RUNTIME_DIR/.venv/bin/python" -m pip install --upgrade pip
"$RUNTIME_DIR/.venv/bin/python" -m pip install -r requirements.txt
"$RUNTIME_DIR/.venv/bin/python" -m pip install --upgrade "${ARDUPILOT_PYTHON_PKGS[@]}"
export PATH="$RUNTIME_DIR/.venv/bin:$PATH"

msg "Checking the machine"
if ! ./bin/check_environment; then
  cat <<EOF

Environment check failed.

Try this repair command:
  cd "$RUNTIME_DIR"
  "$RUNTIME_DIR/.venv/bin/python" -m pip install --upgrade -r requirements.txt
  "$RUNTIME_DIR/.venv/bin/python" -m pip install --upgrade dronecan empy==3.3.4 flake8 geocoder intelhex junitparser lxml MAVProxy numpy pexpect psutil ptyprocess pymavlink pyparsing pyserial PyYAML tabulate wsproto
  ./bin/check_environment
EOF
  exit 1
fi

cat <<EOF

Setup finished.

Next terminal command:
  cd "$RUNTIME_DIR"

Then start the simulator:
  bash "$RUNTIME_DIR/bin/run_sim.sh"

If this is the same terminal, PATH is already updated.
If you open a new terminal, it will pick up the PATH change automatically.
EOF

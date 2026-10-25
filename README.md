# USV SITL Flight Controller Emulator

A local Ubuntu runtime that stands in for a USV's Pixhawk flight controller, so
autonomy software can be built and tested without the physical hardware.

It runs ArduRover SITL in a motorboat configuration, exposes the vehicle through
MAVLink2REST (HTTP and WebSocket), and publishes a compact JSON telemetry stream
over UDP for downstream autonomy clients.

## Why I built this

To unblock an autonomy team that needed to develop and test against a USV's flight-controller interface without access to the physical Pixhawk hardware. Rather than tie their work to a real controller they could not easily get, I emulated it: the same ArduRover SITL flight-controller behaviour, the same MAVLink interface, and a clean JSON telemetry feed, all runnable locally. It turned a hardware dependency that would have stalled their integration into something they could clone and run in minutes on their own machines.

## How it fits together

```text
ArduRover SITL (motorboat frame, mav.parm)
  |
  +-- MAVLink  udp 127.0.0.1:14551 --> src/mavlink_to_json.py --> JSON  udp 127.0.0.1:16000 --> your client
  |                                                                                          (or src/json_receiver.py)
  |
  +-- MAVLink  udp 127.0.0.1:14552 --> MAVLink2REST --> HTTP + WebSocket on port 8088
```

| Port | What listens there |
| --- | --- |
| `14551/udp` | `mavlink_to_json.py`, reading MAVLink from SITL |
| `14552/udp` | MAVLink2REST, reading MAVLink from SITL |
| `8088/tcp` | MAVLink2REST API (`/mavlink`, `/ws/mavlink`, and the versioned `/v1/...` paths) |
| `16000/udp` | the JSON telemetry stream, received by `json_receiver.py` or your own client |

MAVLink2REST binds to `0.0.0.0:8088` by default, so other machines on the same
network can reach it. Set `SERVER_BIND_ADDR=127.0.0.1:8088` to keep it local.

## Tech stack

- Bash for setup, packaging, startup, environment checks, and command tests
- Python for MAVLink telemetry parsing and UDP JSON output
- ArduPilot ArduRover SITL for flight-controller emulation
- MAVProxy and pymavlink for MAVLink routing and log handling
- MAVLink2REST for HTTP access to MAVLink messages and commands

## Quick start

Works on Ubuntu, WSL Ubuntu, or Jetson Linux.

```bash
git clone https://github.com/n0711/usv-sitl-flight-controller-emulator.git
cd usv-sitl-flight-controller-emulator
bash tools/setup_ubuntu.sh
```

`setup_ubuntu.sh` installs the apt packages, clones ArduPilot into
`~/ardupilot` (override with `ARDUPILOT_DIR`) and runs its Ubuntu prerequisites
script, downloads the MAVLink2REST 1.0.2 binary to `/usr/local/bin` (x86_64 or
aarch64), and creates a Python virtual environment in `.venv` with
`requirements.txt`. It asks for `sudo`. Open a new terminal afterwards so the
ArduPilot tools are on `PATH`.

Then use three terminals:

```bash
# 1. Start SITL and MAVLink2REST
bash run_sim.sh

# 2. Start the JSON telemetry bridge
.venv/bin/python src/mavlink_to_json.py

# 3. Watch the JSON stream
.venv/bin/python src/json_receiver.py
```

With SITL running, check the command path end to end:

```bash
bash tools/command_test.sh
```

It reads a `HEARTBEAT` through MAVLink2REST, then sends GUIDED mode, arm, a
1 m/s body-frame velocity setpoint, HOLD mode, and disarm. Point it at another
server with `MAVLINK2REST_URL`.

## Start at a real position

`tools/start_from_log.sh` reads the first GPS fix from an ArduPilot `.BIN` log
and starts SITL there, so the simulated boat begins where a real one was.

```bash
bash tools/start_from_log.sh --print-location path/to/log.bin   # only print SITL_LOCATION
bash tools/start_from_log.sh path/to/log.bin                    # start SITL at that spot
bash tools/start_from_log.sh path/to/log.bin 90                 # same, heading 90 degrees
```

With no path, it uses the single `.BIN` file in `logs/`.

## JSON telemetry

`mavlink_to_json.py` sends one message per `GLOBAL_POSITION_INT`:

```json
{
  "timestamp": "2026-04-07T08:58:50Z",
  "vehicle_id": 1,
  "message_type": "vehicle_state",
  "position": {"latitude_deg": 0.0, "longitude_deg": 0.0},
  "motion": {"groundspeed_mps": 0.0, "heading_deg": 0.0},
  "navigation": {"gps_fix": 0, "ekf_healthy": false},
  "system": {"mode": "MANUAL", "armed": false, "battery_voltage_v": 0.0}
}
```

Fields come from `GLOBAL_POSITION_INT`, `GPS_RAW_INT`, `VFR_HUD`, `SYS_STATUS`
and `HEARTBEAT`. `ekf_healthy` is a placeholder for now and always reads
`false`.

Options:

```bash
.venv/bin/python src/mavlink_to_json.py [target_ip] [--target-port 16000] [--mavlink-in udpin:127.0.0.1:14551]
```

For the MAVLink2REST message envelope and command examples, see
[`docs/mavlink2rest_integration.md`](docs/mavlink2rest_integration.md).

## Configuration

`run_sim.sh` reads these environment variables:

| Variable | Default |
| --- | --- |
| `VEHICLE` | `Rover` |
| `FRAME` | `motorboat` |
| `PARAM_FILE` | `mav.parm` next to the script |
| `SITL_LOCATION` | ArduPilot default (`lat,lon,alt,heading`) |
| `SERVER_BIND_ADDR` | `0.0.0.0:8088` |
| `MAVLINK_JSON_OUT` | `udp:127.0.0.1:14551` |
| `MAVLINK2REST_OUT` | `udp:127.0.0.1:14552` |
| `MAVLINK2REST_CONNECT` | `udpin:127.0.0.1:14552` |
| `MAVLINK2REST_BIN` | `mavlink2rest` |

`mav.parm` is a full ArduRover parameter set for the USV. SITL starts with
`--wipe-eeprom`, so every run begins from that file.

## Handoff package

For a team that should run the emulator without the source tree:

```bash
bash tools/build_handoff.sh
```

This writes `build/usv-sitl-ai-team-handoff.zip`. Set `SAMPLE_LOG` to include an
ArduPilot log. The zip holds `setup_ubuntu.sh`, `TEST_INSTRUCTIONS.md`, a
`sample_logs/` folder, `SHA256SUMS.txt`, and the runtime archive
`usv-sitl-interface-runtime.tar.gz`, which contains:

```text
bin/check_environment
bin/command_test
bin/json_receiver
bin/mavlink_to_json
bin/run_sim.sh
bin/setup_ubuntu
bin/start_from_log
lib/*.pyc
docs/
logs/
mav.parm
requirements.txt
README.md and USAGE.md (copies of this file)
```

The receiving team follows [`TEST_INSTRUCTIONS.md`](TEST_INSTRUCTIONS.md) from
top to bottom.

## Repository layout

```text
run_sim.sh               starts MAVLink2REST and ArduRover SITL
mav.parm                 USV parameter set loaded on every start
src/mavlink_to_json.py   MAVLink to compact UDP JSON bridge
src/json_receiver.py     prints the JSON stream on 127.0.0.1:16000
tools/                   setup, environment check, command test, log start, packaging
docs/                    MAVLink2REST integration guide for the autonomy client
TEST_INSTRUCTIONS.md     step-by-step test script for the handoff package
```

## Limits

This is a local simulation and integration-test environment. It is not a
replacement for hardware-in-the-loop testing or for validation on a real
vessel.

## Support this project

If this project is useful to you, you can support its development with a one-off contribution via Revolut:

**[revolut.me/nadiotis](https://revolut.me/nadiotis)**

# USV SITL Flight Controller Emulator

A local Ubuntu-based runtime for testing unmanned surface vehicle autonomy
interfaces without physical flight-controller hardware.

The project uses ArduRover SITL to emulate a Pixhawk-style USV controller,
MAVLink2REST to expose a local HTTP API, and Python utilities to publish compact
JSON telemetry for downstream autonomy clients.

## Tech Stack

- Bash for setup, packaging, startup, environment checks, and command tests
- Python for MAVLink telemetry parsing and UDP JSON output
- ArduPilot ArduRover SITL for flight-controller emulation
- MAVProxy and pymavlink for MAVLink routing and log handling
- MAVLink2REST for HTTP access to MAVLink messages and commands

## Features

- Start ArduRover SITL in a motorboat configuration
- Expose MAVLink messages and commands through `http://127.0.0.1:8088`
- Convert MAVLink telemetry into compact UDP JSON on `127.0.0.1:16000`
- Start the simulation from the first GPS point in an ArduPilot `.BIN` log
- Run an automated command test for GUIDED mode, arm, movement setpoint, HOLD,
  and disarm
- Build a runtime handoff package for Ubuntu testing

## Quick Start

Clone the repository on Ubuntu, WSL Ubuntu, or Jetson Linux:

```bash
git clone https://github.com/n0711/usv-sitl-flight-controller-emulator.git
cd usv-sitl-flight-controller-emulator
```

Install the runtime dependencies:

```bash
bash tools/setup_ubuntu.sh
```

Start SITL:

```bash
bash run_sim.sh
```

In another terminal, start the JSON telemetry bridge:

```bash
python3 src/mavlink_to_json.py
```

In a third terminal, view the JSON telemetry:

```bash
python3 src/json_receiver.py
```

With SITL running, run the command test:

```bash
bash tools/command_test.sh
```

For packaged runtime testing, build the handoff archive and follow
`TEST_INSTRUCTIONS.md`:

```bash
bash tools/build_handoff.sh
```

## Runtime Package

The runtime package contains:

```text
bin/check_environment
bin/command_test
bin/run_sim.sh
bin/setup_ubuntu
bin/start_from_log
bin/mavlink_to_json
bin/json_receiver
lib/*.pyc
mav.parm
requirements.txt
docs/
```

## Notes

This is a local simulation and integration-test environment. It is not a full
replacement for hardware-in-the-loop testing or physical vessel validation.

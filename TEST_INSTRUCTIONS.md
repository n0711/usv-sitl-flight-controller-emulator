# USV SITL Runtime Test Instructions

Follow this file from top to bottom on Ubuntu, WSL Ubuntu, or Jetson Linux.

## 1. Put The New Zip In Downloads

Put the latest file here:

```text
~/Downloads/usv-sitl-ai-team-handoff.zip
```

Use the newest zip. Do not reuse an old extracted `~/usv_sitl_test` folder.

## 2. Clean Install

Open an Ubuntu terminal and paste this whole block:

```bash
sudo apt update
sudo apt install -y unzip tar
pkill -f 'mavlink2rest|sim_vehicle.py|mavproxy.py|ardurover|mavlink_to_json|json_receiver' 2>/dev/null || true
rm -rf ~/usv_sitl_test
mkdir -p ~/usv_sitl_test
cd ~/usv_sitl_test
unzip -o ~/Downloads/usv-sitl-ai-team-handoff.zip -d .
bash ./setup_ubuntu.sh
```

Expected result near the end:

```text
Environment check passed.
Setup finished.
```

If Ubuntu asks for a password, type the Ubuntu password and press Enter. It is
normal that the password does not show while typing.

## 3. Copy The Sample Log

Paste:

```bash
cd ~/usv_sitl_test/usv-sitl-interface-runtime
cp ../sample_logs/2026-04-07\ 11-58-50.bin logs/
bash "$HOME/usv_sitl_test/usv-sitl-interface-runtime/bin/start_from_log" --print-location "logs/2026-04-07 11-58-50.bin"
```

Expected result:

```text
SITL_LOCATION="lat,lon,alt,heading"
```

## 4. Start SITL

In Terminal 1, paste:

```bash
cd ~/usv_sitl_test/usv-sitl-interface-runtime
bash "$HOME/usv_sitl_test/usv-sitl-interface-runtime/bin/start_from_log" "logs/2026-04-07 11-58-50.bin"
```

Leave this terminal running.

Wait until it shows:

```text
Detected vehicle 1:1
Mode MANUAL
ArduPilot Ready
```

## 5. Start JSON Telemetry

Open Terminal 2 and paste:

```bash
cd ~/usv_sitl_test/usv-sitl-interface-runtime
bash "$HOME/usv_sitl_test/usv-sitl-interface-runtime/bin/mavlink_to_json"
```

Open Terminal 3 and paste:

```bash
cd ~/usv_sitl_test/usv-sitl-interface-runtime
bash "$HOME/usv_sitl_test/usv-sitl-interface-runtime/bin/json_receiver"
```

Expected result: Terminal 3 prints JSON telemetry.

## 6. Open MAVLink2REST

Open this in Firefox:

```text
http://127.0.0.1:8088
```

Expected result: a MAVLink2REST page opens.

## 7. Run Command Test

Keep Terminal 1 running. Open Terminal 4 and paste:

```bash
cd ~/usv_sitl_test/usv-sitl-interface-runtime
bash "$HOME/usv_sitl_test/usv-sitl-interface-runtime/bin/command_test"
```

Expected result:

```text
HTTP 200
HTTP 200
HTTP 200
HEARTBEAT
HTTP 200
HTTP 200
Command test complete.
```

The HEARTBEAT line should print JSON. It is okay if the JSON is long.

## 8. Stop Everything

Press `Ctrl+C` in every running terminal.

If something is stuck, paste:

```bash
pkill -f 'mavlink2rest|sim_vehicle.py|mavproxy.py|ardurover|mavlink_to_json|json_receiver'
```

## If Something Fails

Send back:

- the command you ran
- the last 30 terminal lines
- whether you used the newest `usv-sitl-ai-team-handoff.zip`

Common fixes:

- `cannot find or open ...zip`: put `usv-sitl-ai-team-handoff.zip` in `~/Downloads`
- `ModuleNotFoundError`: rerun section 2 with the newest zip
- `Address already in use`: run the `pkill` command in section 8, then start again
- command test says not found: rerun section 2 with the newest zip

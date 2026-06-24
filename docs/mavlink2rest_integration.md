# USV MAVLink2REST AI Vendor Integration Guide

This document defines the clean JSON contract for an external AI service that consumes USV telemetry and sends high-level vehicle commands through MAVLink2REST.

## Endpoints

Project-facing endpoints:

- WebSocket telemetry: `ws://127.0.0.1:8088/ws/mavlink`
- REST command ingress: `POST http://127.0.0.1:8088/mavlink`

Upstream mavlink2rest deployments commonly expose the same interfaces under versioned paths:

- `ws://127.0.0.1:8088/v1/ws/mavlink`
- `POST http://127.0.0.1:8088/v1/mavlink`

Use the project-facing endpoints first. If the server returns `404`, retry the versioned endpoint.

## Message Envelope

Telemetry and commands use the mavlink2rest JSON envelope:

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "COMMAND_LONG"
  }
}
```

For outgoing commands, use `system_id: 255` and `component_id: 0` for the middleware/GCS sender unless your deployment assigns a different sender ID.

Default target IDs:

- `target_system: 1`
- `target_component: 1`

## WebSocket Telemetry Subscription

MAVLink2REST streams all MAVLink messages over the WebSocket. An autonomy client can subscribe once, filter by `message.type`, and normalize only the telemetry types it needs.

Required streams:

- `GLOBAL_POSITION_INT`: GPS position, relative altitude, velocity, and heading
- `ATTITUDE`: roll, pitch, yaw, and body angular rates
- `HEARTBEAT`: autopilot type, armed state, mode flags, and system status

### JavaScript WebSocket Client

```js
const wsUrl = "ws://127.0.0.1:8088/ws/mavlink";
const ws = new WebSocket(wsUrl);

const MAV_MODE_FLAG_SAFETY_ARMED = 128;

function normalizeMavlink(packet) {
  const msg = packet.message;
  if (!msg || !msg.type) return null;

  switch (msg.type) {
    case "GLOBAL_POSITION_INT":
      return {
        stream: "gps",
        source: {
          system_id: packet.header?.system_id,
          component_id: packet.header?.component_id
        },
        time_boot_ms: msg.time_boot_ms,
        latitude_deg: msg.lat / 1e7,
        longitude_deg: msg.lon / 1e7,
        altitude_msl_m: msg.alt / 1000,
        altitude_relative_m: msg.relative_alt / 1000,
        velocity_mps: {
          north: msg.vx / 100,
          east: msg.vy / 100,
          down: msg.vz / 100
        },
        heading_deg: msg.hdg === 65535 ? null : msg.hdg / 100
      };

    case "ATTITUDE":
      return {
        stream: "attitude",
        source: {
          system_id: packet.header?.system_id,
          component_id: packet.header?.component_id
        },
        time_boot_ms: msg.time_boot_ms,
        roll_rad: msg.roll,
        pitch_rad: msg.pitch,
        yaw_rad: msg.yaw,
        rollspeed_rad_s: msg.rollspeed,
        pitchspeed_rad_s: msg.pitchspeed,
        yawspeed_rad_s: msg.yawspeed
      };

    case "HEARTBEAT":
      return {
        stream: "heartbeat",
        source: {
          system_id: packet.header?.system_id,
          component_id: packet.header?.component_id
        },
        mav_type: msg.mavtype,
        autopilot: msg.autopilot,
        base_mode: msg.base_mode,
        custom_mode: msg.custom_mode,
        system_status: msg.system_status,
        mavlink_version: msg.mavlink_version,
        armed: (msg.base_mode & MAV_MODE_FLAG_SAFETY_ARMED) !== 0
      };

    default:
      return null;
  }
}

ws.onopen = () => {
  console.log("Connected to MAVLink2REST telemetry stream");
};

ws.onmessage = (event) => {
  const packet = JSON.parse(event.data);
  const telemetry = normalizeMavlink(packet);
  if (!telemetry) return;

  // Forward telemetry to AI perception, planning, or logging pipelines here.
  console.log(JSON.stringify(telemetry));
};

ws.onerror = (error) => {
  console.error("MAVLink2REST WebSocket error", error);
};

ws.onclose = () => {
  console.warn("MAVLink2REST WebSocket closed");
};
```

### Python Async WebSocket Client

```python
import asyncio
import json
import websockets

WS_URL = "ws://127.0.0.1:8088/ws/mavlink"
MAV_MODE_FLAG_SAFETY_ARMED = 128


def normalize(packet):
    msg = packet.get("message", {})
    msg_type = msg.get("type")

    if msg_type == "GLOBAL_POSITION_INT":
        return {
            "stream": "gps",
            "source": packet.get("header", {}),
            "time_boot_ms": msg["time_boot_ms"],
            "latitude_deg": msg["lat"] / 1e7,
            "longitude_deg": msg["lon"] / 1e7,
            "altitude_msl_m": msg["alt"] / 1000,
            "altitude_relative_m": msg["relative_alt"] / 1000,
            "velocity_mps": {
                "north": msg["vx"] / 100,
                "east": msg["vy"] / 100,
                "down": msg["vz"] / 100,
            },
            "heading_deg": None if msg["hdg"] == 65535 else msg["hdg"] / 100,
        }

    if msg_type == "ATTITUDE":
        return {
            "stream": "attitude",
            "source": packet.get("header", {}),
            "time_boot_ms": msg["time_boot_ms"],
            "roll_rad": msg["roll"],
            "pitch_rad": msg["pitch"],
            "yaw_rad": msg["yaw"],
            "rollspeed_rad_s": msg["rollspeed"],
            "pitchspeed_rad_s": msg["pitchspeed"],
            "yawspeed_rad_s": msg["yawspeed"],
        }

    if msg_type == "HEARTBEAT":
        base_mode = msg["base_mode"]
        return {
            "stream": "heartbeat",
            "source": packet.get("header", {}),
            "mav_type": msg["mavtype"],
            "autopilot": msg["autopilot"],
            "base_mode": base_mode,
            "custom_mode": msg["custom_mode"],
            "system_status": msg["system_status"],
            "mavlink_version": msg["mavlink_version"],
            "armed": (base_mode & MAV_MODE_FLAG_SAFETY_ARMED) != 0,
        }

    return None


async def main():
    async with websockets.connect(WS_URL) as ws:
        async for raw in ws:
            packet = json.loads(raw)
            telemetry = normalize(packet)
            if telemetry:
                print(json.dumps(telemetry))


asyncio.run(main())
```

## REST Command Interface

Send commands with:

```bash
curl -X POST "http://127.0.0.1:8088/mavlink" \
  -H "Content-Type: application/json" \
  -d '<payload>'
```

If the unversioned endpoint is unavailable, use:

```bash
curl -X POST "http://127.0.0.1:8088/v1/mavlink" \
  -H "Content-Type: application/json" \
  -d '<payload>'
```

## Command Payloads

### ARM

Uses `COMMAND_LONG` with `MAV_CMD_COMPONENT_ARM_DISARM` (`400`) and `param1: 1`.

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "COMMAND_LONG",
    "target_system": 1,
    "target_component": 1,
    "command": {
      "type": "MAV_CMD_COMPONENT_ARM_DISARM"
    },
    "confirmation": 0,
    "param1": 1,
    "param2": 0,
    "param3": 0,
    "param4": 0,
    "param5": 0,
    "param6": 0,
    "param7": 0
  }
}
```

Numeric-command fallback:

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "COMMAND_LONG",
    "target_system": 1,
    "target_component": 1,
    "command": 400,
    "confirmation": 0,
    "param1": 1,
    "param2": 0,
    "param3": 0,
    "param4": 0,
    "param5": 0,
    "param6": 0,
    "param7": 0
  }
}
```

### DISARM

Uses `COMMAND_LONG` with `MAV_CMD_COMPONENT_ARM_DISARM` (`400`) and `param1: 0`.

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "COMMAND_LONG",
    "target_system": 1,
    "target_component": 1,
    "command": {
      "type": "MAV_CMD_COMPONENT_ARM_DISARM"
    },
    "confirmation": 0,
    "param1": 0,
    "param2": 0,
    "param3": 0,
    "param4": 0,
    "param5": 0,
    "param6": 0,
    "param7": 0
  }
}
```

### Force STOP by Switching to HOLD

For ArduPilot Rover/USV, HOLD mode is `custom_mode: 4`. This should stop active guided motion and hold position where the vehicle is.

Preferred payload using `SET_MODE`:

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "SET_MODE",
    "target_system": 1,
    "base_mode": {
      "bits": 1
    },
    "custom_mode": 4
  }
}
```

Numeric fallback:

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "SET_MODE",
    "target_system": 1,
    "base_mode": 1,
    "custom_mode": 4
  }
}
```

Alternative payload using `COMMAND_LONG` and `MAV_CMD_DO_SET_MODE` (`176`):

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "COMMAND_LONG",
    "target_system": 1,
    "target_component": 1,
    "command": {
      "type": "MAV_CMD_DO_SET_MODE"
    },
    "confirmation": 0,
    "param1": 1,
    "param2": 4,
    "param3": 0,
    "param4": 0,
    "param5": 0,
    "param6": 0,
    "param7": 0
  }
}
```

### Dynamic STEERING with SET_POSITION_TARGET_LOCAL_NED

Use this for velocity plus yaw-rate steering while the vehicle is in GUIDED mode.

Recommended control semantics:

- Coordinate frame: `MAV_FRAME_BODY_NED` (`8`)
- `vx`: forward speed in meters per second
- `vy`: lateral speed in meters per second, normally `0` for a USV/rover
- `vz`: vertical speed in meters per second, normally `0` for a USV/rover
- `yaw_rate`: turn rate in radians per second, positive clockwise in the MAVLink body frame
- `type_mask: 1479`: ignore position, acceleration, and yaw; use velocity vector and yaw rate

Example: move forward at `1.2 m/s` while turning right at `0.35 rad/s`.

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "SET_POSITION_TARGET_LOCAL_NED",
    "time_boot_ms": 0,
    "target_system": 1,
    "target_component": 1,
    "coordinate_frame": {
      "type": "MAV_FRAME_BODY_NED"
    },
    "type_mask": {
      "bits": 1479
    },
    "x": 0,
    "y": 0,
    "z": 0,
    "vx": 1.2,
    "vy": 0,
    "vz": 0,
    "afx": 0,
    "afy": 0,
    "afz": 0,
    "yaw": 0,
    "yaw_rate": 0.35
  }
}
```

Numeric fallback:

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "SET_POSITION_TARGET_LOCAL_NED",
    "time_boot_ms": 0,
    "target_system": 1,
    "target_component": 1,
    "coordinate_frame": 8,
    "type_mask": 1479,
    "x": 0,
    "y": 0,
    "z": 0,
    "vx": 1.2,
    "vy": 0,
    "vz": 0,
    "afx": 0,
    "afy": 0,
    "afz": 0,
    "yaw": 0,
    "yaw_rate": 0.35
  }
}
```

Stop motion while remaining in GUIDED mode:

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "SET_POSITION_TARGET_LOCAL_NED",
    "time_boot_ms": 0,
    "target_system": 1,
    "target_component": 1,
    "coordinate_frame": 8,
    "type_mask": 1479,
    "x": 0,
    "y": 0,
    "z": 0,
    "vx": 0,
    "vy": 0,
    "vz": 0,
    "afx": 0,
    "afy": 0,
    "afz": 0,
    "yaw": 0,
    "yaw_rate": 0
  }
}
```

## Mode Prerequisite for Steering

Dynamic steering normally requires GUIDED mode before velocity/yaw-rate setpoints are accepted. For ArduPilot Rover/USV, GUIDED mode is `custom_mode: 15`.

```json
{
  "header": {
    "system_id": 255,
    "component_id": 0,
    "sequence": 0
  },
  "message": {
    "type": "SET_MODE",
    "target_system": 1,
    "base_mode": 1,
    "custom_mode": 15
  }
}
```

## Python Command Helper

```python
import requests

REST_URL = "http://127.0.0.1:8088/mavlink"


def post_mavlink(message):
    payload = {
        "header": {
            "system_id": 255,
            "component_id": 0,
            "sequence": 0,
        },
        "message": message,
    }
    response = requests.post(REST_URL, json=payload, timeout=2)
    response.raise_for_status()
    return response.json() if response.content else None


def arm():
    return post_mavlink({
        "type": "COMMAND_LONG",
        "target_system": 1,
        "target_component": 1,
        "command": {"type": "MAV_CMD_COMPONENT_ARM_DISARM"},
        "confirmation": 0,
        "param1": 1,
        "param2": 0,
        "param3": 0,
        "param4": 0,
        "param5": 0,
        "param6": 0,
        "param7": 0,
    })


def disarm():
    return post_mavlink({
        "type": "COMMAND_LONG",
        "target_system": 1,
        "target_component": 1,
        "command": {"type": "MAV_CMD_COMPONENT_ARM_DISARM"},
        "confirmation": 0,
        "param1": 0,
        "param2": 0,
        "param3": 0,
        "param4": 0,
        "param5": 0,
        "param6": 0,
        "param7": 0,
    })


def hold_stop():
    return post_mavlink({
        "type": "SET_MODE",
        "target_system": 1,
        "base_mode": 1,
        "custom_mode": 4,
    })


def set_guided():
    return post_mavlink({
        "type": "SET_MODE",
        "target_system": 1,
        "base_mode": 1,
        "custom_mode": 15,
    })


def steer(forward_mps, yaw_rate_rad_s):
    return post_mavlink({
        "type": "SET_POSITION_TARGET_LOCAL_NED",
        "time_boot_ms": 0,
        "target_system": 1,
        "target_component": 1,
        "coordinate_frame": 8,
        "type_mask": 1479,
        "x": 0,
        "y": 0,
        "z": 0,
        "vx": forward_mps,
        "vy": 0,
        "vz": 0,
        "afx": 0,
        "afy": 0,
        "afz": 0,
        "yaw": 0,
        "yaw_rate": yaw_rate_rad_s,
    })
```

## Operational Notes

- Treat `HEARTBEAT` as the source of truth for `armed`, `base_mode`, `custom_mode`, and vehicle health state.
- Confirm the vehicle has entered GUIDED mode before streaming steering setpoints.
- Send steering setpoints continuously at `2-10 Hz`; many autopilots stop honoring setpoints after a short timeout.
- For emergency stop, prefer switching to HOLD mode over sending a single zero-velocity setpoint.
- Validate all external AI outputs before forwarding commands: clamp speed, clamp yaw rate, and reject commands if telemetry is stale.

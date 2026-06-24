import argparse
import json
import socket
import time
from pymavlink import mavutil

DEFAULT_MAVLINK_IN = "udpin:127.0.0.1:14551"
DEFAULT_JSON_HOST = "127.0.0.1"
DEFAULT_JSON_PORT = 16000


def build_parser():
    parser = argparse.ArgumentParser(
        description="Convert SITL MAVLink telemetry to a compact USV JSON stream."
    )
    parser.add_argument(
        "target_ip",
        nargs="?",
        default=DEFAULT_JSON_HOST,
        help=f"UDP JSON receiver IP address. Defaults to {DEFAULT_JSON_HOST}.",
    )
    parser.add_argument(
        "--target-port",
        type=int,
        default=DEFAULT_JSON_PORT,
        help=f"UDP JSON receiver port. Defaults to {DEFAULT_JSON_PORT}.",
    )
    parser.add_argument(
        "--mavlink-in",
        default=DEFAULT_MAVLINK_IN,
        help=f"pymavlink connection string. Defaults to {DEFAULT_MAVLINK_IN}.",
    )
    return parser


def main():
    args = build_parser().parse_args()

    mav_conn = mavutil.mavlink_connection(args.mavlink_in)
    json_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    json_receiver_address = (args.target_ip, args.target_port)

    vehicle_state = {
        "timestamp": "",
        "vehicle_id": 1,
        "message_type": "vehicle_state",
        "position": {"latitude_deg": 0.0, "longitude_deg": 0.0},
        "motion": {"groundspeed_mps": 0.0, "heading_deg": 0.0},
        "navigation": {"gps_fix": 0, "ekf_healthy": False},
        "system": {"mode": "MANUAL", "armed": False, "battery_voltage_v": 0.0},
    }

    print(f"Listening for MAVLink telemetry on {args.mavlink_in}...")
    print(f"Streaming compact JSON telemetry to {args.target_ip}:{args.target_port}")

    while True:
        msg = mav_conn.recv_match(blocking=True)
        if not msg:
            continue

        msg_type = msg.get_type()
        vehicle_state["timestamp"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

        if msg_type == 'GLOBAL_POSITION_INT':
            vehicle_state["position"]["latitude_deg"] = msg.lat / 1e7
            vehicle_state["position"]["longitude_deg"] = msg.lon / 1e7
            vehicle_state["motion"]["heading_deg"] = msg.hdg / 100.0

        elif msg_type == 'GPS_RAW_INT':
            vehicle_state["navigation"]["gps_fix"] = msg.fix_type

        elif msg_type == 'VFR_HUD':
            vehicle_state["motion"]["groundspeed_mps"] = msg.groundspeed

        elif msg_type == 'SYS_STATUS':
            vehicle_state["system"]["battery_voltage_v"] = msg.voltage_battery / 1000.0

        elif msg_type == 'HEARTBEAT':
            is_armed = (msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED) != 0
            vehicle_state["system"]["armed"] = is_armed
            vehicle_state["system"]["mode"] = mavutil.mode_string_v10(msg)

        if msg_type == 'GLOBAL_POSITION_INT':
            json_payload = json.dumps(vehicle_state)
            json_sock.sendto(json_payload.encode('utf-8'), json_receiver_address)
            print(
                "Sent JSON State -> "
                f"Lat: {vehicle_state['position']['latitude_deg']}, "
                f"Lon: {vehicle_state['position']['longitude_deg']}"
            )


if __name__ == '__main__':
    main()

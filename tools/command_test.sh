#!/usr/bin/env bash
set -Eeuo pipefail

BASE_URL="${MAVLINK2REST_URL:-http://127.0.0.1:8088}"
TMP_BODY="$(mktemp)"

cleanup() {
  rm -f "$TMP_BODY"
}
trap cleanup EXIT

post_mavlink() {
  local label="$1"
  local payload="$2"
  local status

  printf '\n==> %s\n' "$label"
  status="$(
    curl -sS -o "$TMP_BODY" -w '%{http_code}' \
      -X POST "${BASE_URL}/v1/mavlink" \
      -H "Content-Type: application/json" \
      -d "$payload"
  )"

  printf 'HTTP %s\n' "$status"
  if [[ "$status" != "200" ]]; then
    cat "$TMP_BODY"
    printf '\n'
    exit 1
  fi
}

get_heartbeat() {
  printf '\n==> HEARTBEAT\n'
  curl -sS "${BASE_URL}/v1/mavlink/vehicles/1/components/1/messages/HEARTBEAT"
  printf '\n'
}

post_mavlink "Set GUIDED mode" \
'{"header":{"system_id":255,"component_id":0,"sequence":0},"message":{"type":"COMMAND_LONG","target_system":1,"target_component":1,"command":{"type":"MAV_CMD_DO_SET_MODE"},"confirmation":0,"param1":1,"param2":15,"param3":0,"param4":0,"param5":0,"param6":0,"param7":0}}'

post_mavlink "Arm" \
'{"header":{"system_id":255,"component_id":0,"sequence":0},"message":{"type":"COMMAND_LONG","target_system":1,"target_component":1,"command":{"type":"MAV_CMD_COMPONENT_ARM_DISARM"},"confirmation":0,"param1":1,"param2":0,"param3":0,"param4":0,"param5":0,"param6":0,"param7":0}}'

post_mavlink "Send one movement setpoint" \
'{"header":{"system_id":255,"component_id":0,"sequence":0},"message":{"type":"SET_POSITION_TARGET_LOCAL_NED","time_boot_ms":0,"target_system":1,"target_component":1,"coordinate_frame":{"type":"MAV_FRAME_BODY_NED"},"type_mask":"POSITION_TARGET_TYPEMASK_X_IGNORE | POSITION_TARGET_TYPEMASK_Y_IGNORE | POSITION_TARGET_TYPEMASK_Z_IGNORE | POSITION_TARGET_TYPEMASK_AX_IGNORE | POSITION_TARGET_TYPEMASK_AY_IGNORE | POSITION_TARGET_TYPEMASK_AZ_IGNORE | POSITION_TARGET_TYPEMASK_YAW_IGNORE","x":0,"y":0,"z":0,"vx":1.0,"vy":0,"vz":0,"afx":0,"afy":0,"afz":0,"yaw":0,"yaw_rate":0.25}}'

get_heartbeat

post_mavlink "Set HOLD mode" \
'{"header":{"system_id":255,"component_id":0,"sequence":0},"message":{"type":"COMMAND_LONG","target_system":1,"target_component":1,"command":{"type":"MAV_CMD_DO_SET_MODE"},"confirmation":0,"param1":1,"param2":4,"param3":0,"param4":0,"param5":0,"param6":0,"param7":0}}'

post_mavlink "Disarm" \
'{"header":{"system_id":255,"component_id":0,"sequence":0},"message":{"type":"COMMAND_LONG","target_system":1,"target_component":1,"command":{"type":"MAV_CMD_COMPONENT_ARM_DISARM"},"confirmation":0,"param1":0,"param2":0,"param3":0,"param4":0,"param5":0,"param6":0,"param7":0}}'

printf '\nCommand test complete.\n'

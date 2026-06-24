import socket
import json


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('127.0.0.1', 16000))
    print("Listening for JSON payloads on UDP port 16000...")

    while True:
        data, addr = sock.recvfrom(4096)
        try:
            payload = json.loads(data.decode('utf-8'))
            print("\n--- Received Telemetry Update ---")
            print(json.dumps(payload, indent=2))
        except Exception as e:
            print(f"Error parsing incoming JSON packet: {e}")


if __name__ == '__main__':
    main()

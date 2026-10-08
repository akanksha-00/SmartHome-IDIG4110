# smart_home

A new Flutter project.

## Local API through an SSH tunnel

When the remote backend has no CORS headers, use the local proxy for Flutter web.

1. Keep the SSH tunnel running in a terminal:

   ```sh
   ssh -i ~/SmartHomeKey.pem -N -L 8001:127.0.0.1:8001 ubuntu@10.212.170.109
   ```

2. In another terminal, from `frontend/smart_home`, run:

   ```sh
   python3 tool/local_api_proxy.py
   ```

3. Run Flutter in Chrome or hot restart it. `ApiEndpoints.baseUrl` points to
   `http://127.0.0.1:8002`; the proxy forwards requests to the tunnel on port 8001.

Keep both terminals running. The proxy supports device and room HTTP requests,
including JSON POST and PATCH preflights. It listens only on your Mac's loopback
address and permits local Flutter origins. WebSockets use a separate connection.

## Live devices and dashboard alerts

The app opens one connection for `house-001` at
`ws://127.0.0.1:8001/api/v1/houses/house-001/ws`, directly through the SSH tunnel.
`ApiEndpoints.webSocketBaseUrl` configures this separately from the HTTP proxy.
For another server, use `--dart-define=SMART_HOME_WS_BASE_URL=wss://your-server`.

- Initial device/room data and Add Device still use HTTP. The socket has no
  initial snapshot, subscription message, or create-device command.
- `device_state` merges partial capability values into the device BLoC.
  `device_event` updates its named capability and shows a dashboard notification
  only when the backend sends `alert: true`.
- Sensor cards, 3D markers and the selected room's temperature popup consume
  that same BLoC state. The popup uses its first operational temperature sensor;
  metrics without backend sensor data display `—` instead of sample readings.
- The bell keeps up to 50 alerts received during this app session, with local
  read/cleared indicators. Repeated active alerts for the same device/event do
  not create duplicate notifications. A non-alert event clears that condition.
- After disconnection, the app retries with delays up to 30 seconds and fetches
  a fresh device snapshot on reconnection. Cached devices stay visible.
  Returning to the app also refreshes device data.
- Switches, brightness and fan speed use HTTP PATCH with the backend's array
  of `{name, value}` capability updates. Controls show **Updating…** until the
  response returns, then use the saved device state. This works with dummy
  devices and does not require a live WebSocket connection or an MQTT responder.
  Reports arriving during PATCH take precedence over its response snapshot.
  The current backend does not broadcast PATCH updates; other clients see them
  on their next device refresh. Sensor readings and alerts still use WebSocket.

The backend does not replay missed events or persist notification history.
Reconnecting restores device readings, but alerts emitted while disconnected
cannot be recovered through the current protocol. No backend schema changes or
MQTT simulation publisher are required by this frontend integration.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

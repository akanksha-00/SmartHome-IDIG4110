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
- Switches, brightness and fan speed POST to the device's `/command` endpoint
  with the device's entire current `state` object. DeviceBloc merges each edit
  into the latest loaded/live state and sends all changed and unchanged values.
  For example, switching off a light at 70% sends
  `{"state": {"power": false, "brightness": 70}}`; changing a fan's speed retains
  its power and oscillation values. Controls report edits only; this merge applies
  to every device type. Boolean and numeric values retain their JSON types.
  Controls, counts and 3D markers update immediately while the command publishes
  in the background, with no progress bar or layout change. A failed HTTP request
  restores only the changed values and shows an error; newer WebSocket readings
  are retained. Repeat input for that device is blocked until the HTTP response;
  other devices can publish independently. A concurrent refresh preserves a
  command's optimistic values while its HTTP request is in flight.
- A command response acknowledges MQTT publication, not execution or persisted
  device state. It is never parsed as a device record. Controls become usable on
  that acknowledgement, without waiting for a WebSocket report or MQTT timeout.
  The device (or a simulator) must subscribe to its command topic and publish its
  actual state to its state topic. Those reports update the backend and dashboard
  through WebSocket. Without a responder, the optimistic value can revert on a
  later refresh because the backend still holds the previous reported state.

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

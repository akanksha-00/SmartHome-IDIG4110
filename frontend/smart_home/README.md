# smart_home

A Flutter smart-home dashboard.

## Supabase authentication

The existing sign-in screen and `AuthCubit` use `AuthRepository` to sign in
through `supabase_flutter`. Use an existing email/password account in the
Supabase project; the old dummy credentials work only in automated tests.
Account creation remains unavailable in this screen.

Create `frontend/smart_home/.env` using `.env.example` as the template. Set
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` to the project's URL and public
client key (the legacy `SUPABASE_ANON_KEY` name is also supported). Only public
publishable/anon keys belong in a Flutter app; never use a secret/service-role
key. This local file is ignored by Git and is not bundled as an asset.

From `frontend/smart_home`, start with:

```sh
flutter run -d chrome --dart-define-from-file=.env
```

For deployment, pass the same flag to `flutter build web`. Changing the file
requires stopping and restarting Flutter, since these values are read at build
time. Launching without configuration shows a sign-in configuration error and
does not fall back to demo authentication. See the official
[Supabase Flutter initialization guide](https://supabase.com/docs/reference/dart/initializing).

Sign-in remains session-only: a fresh launch/reload requires signing in again.
Supabase refreshes the session while the app is open; credentials and tokens
are not stored in app/BLoC state. `AuthCubit` listens for session loss, handles
auth stream errors, and closes house state on logout. The sidebar Logout button
and Settings sign-out both use the SDK's local sign-out flow.

After sign-in, `HouseAccessGate` requests `GET /api/v1/houses` with the current
Bearer token and uses the first house authorized by the backend. Empty or failed
responses show a retry/sign-out screen instead of falling back to `house-001`.
Device/room requests and the house WebSocket start only after that house loads.
HTTP headers read the latest SDK token on each request. Each WebSocket connection
sends `{"type":"auth","token":"<current access token>"}` as its first message,
matching the supplied backend test client; no token is placed in the URL.
Reconnections use the refreshed token. Connected status indicates transport
connectivity; the test protocol does not define an authentication acknowledgment.

The FastAPI server's `.env` is separate from this Flutter build configuration.
It must validate tokens from the same Supabase project and implement the
authorized-house and WebSocket authentication behavior. No backend files or
schemas are changed by this frontend integration.

The sign-in illustration is saved at
`assets/images/authentication/smart_home.png`. It was generated with the built-in
image generation tool; the final prompt is in
[the illustration notes](docs/auth_house_illustration.md).

## Live alert notifications

The app bar bell, unread count, alert popup and notification list are backed by
`NotificationBloc` in `lib/src/blocs/notifications/`. The feed starts empty.
It listens to the same `HouseRealtimeRepository` as `DeviceBloc`; no second
socket or notification API is created. `DeviceBloc` owns device readings and
connection status, while `NotificationBloc` owns alert history and read state.

Only backend `device_event` messages with `alert: true` create notifications.
The backend's `notification_message` is displayed as received, with an ID/event
fallback if it is missing. Repeated active events for one device/capability do
not create duplicates. A matching `alert: false` event marks the incident as
cleared; a later active event creates a new incident. State-only reports update
devices without inferring notifications or threshold decisions in Flutter.

Up to 50 incidents are kept newest first for the signed-in house session.
Opening the list does not change read state; tap an entry, its read icon, or
**Mark all as read**. Read and cleared indicators and sequence numbers are local
UI state; nothing is sent back to the backend or added to its message schema.
No timestamps or severity values are assumed, since the stream supplies neither.
History survives reconnection but is disposed on logout and is not replayed by
the backend. The draft notification HTTP repository remains unused.

The backend currently logs threshold alerts calculated from `/state` messages
without broadcasting their alert details. Such a state report can update the
sensor card but cannot produce a notification through the current wire format.
The ownership decision is recorded in
[the live alerts ADR](../../docs/adr/2026-10-20-live-alert-notification-bloc.md).

## Console diagnostics

`lib/src/logging/app_log.dart` provides console logging without a new package or
external service. Logs appear in the terminal running `flutter run` and in
Chrome DevTools **Console**. Filter for `[SmartHome]`, `[ERROR]` or `[WARN]`.
Hot restart after adding this code so the global error handlers are installed.

Each entry has a UTC timestamp, severity and source. HTTP entries include the
method, endpoint path, status (or `none` if no response arrived), and elapsed
milliseconds. They distinguish an unsuccessful HTTP status, a timeout, and an
invalid JSON response. A successful HTTP response can still be followed by a
BLoC failure if its JSON does not match the required device/room schema.
WebSocket entries cover connection state, remote close code, malformed frames,
invalid house messages and scheduled retries. Handled house/device/room/auth
failures are logged where they are caught; a BLoC observer and Flutter/platform
handlers also capture unhandled failures. Existing error screens, command
rollback, retry behavior and Flutter's default error reporting remain in place.

App-owned diagnostics omit headers, tokens, credentials, URL queries/fragments,
raw request/response bodies, WebSocket frames and exception text. They include
exception types and up to ten stack lines instead. Endpoint paths and device/
house IDs can appear as diagnostic context. Normal Flutter/SDK diagnostics are
separate and retain their existing behavior. HTTP timing measures the request,
not the device's MQTT execution time.

Logging is enabled by default for debug/profile builds and disabled for release
builds. Override explicitly with `--dart-define=SMART_HOME_LOGS=true` or `false`.
No log history is persisted or uploaded by the app, and no log viewer is added.
The rationale is recorded in
[the console logging ADR](../../docs/adr/2026-10-20-console-failure-logging.md).

## Local API through an SSH tunnel

When the remote backend has no CORS headers, use the local proxy for Flutter web.

1. Keep the SSH tunnel running in a terminal:

   ```sh
   ssh -i ~/SmartHomeKey.pem -N -L 8000:127.0.0.1:8001 ubuntu@10.212.170.109
   ```

2. In another terminal, from `frontend/smart_home`, run:

   ```sh
   python3 tool/local_api_proxy.py
   ```

3. Run Flutter in Chrome or hot restart it. `ApiEndpoints.baseUrl` points to
   `http://127.0.0.1:8001`; the proxy forwards requests to the tunnel on port 8000.

Keep both terminals running. The proxy supports device and room HTTP requests,
including JSON POST and PATCH preflights. It listens only on your Mac's loopback
address and permits local Flutter origins. WebSockets use a separate connection.

## Live devices and dashboard alerts

The app opens one connection for the signed-in user's selected house at
`ws://127.0.0.1:8000/api/v1/houses/<house_id>/ws`, directly through the SSH tunnel.
`ApiEndpoints.webSocketBaseUrl` configures this separately from the HTTP proxy.
For another server, use `--dart-define=SMART_HOME_WS_BASE_URL=wss://your-server`.

- Initial device/room data and Add Device still use HTTP. The socket has no
  initial snapshot, subscription message, or create-device command. Its first
  frame authenticates with the Supabase access token.
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

# API repositories

The device repository follows the [published OpenAPI schema](https://smarthome-api.abdi-bako.workers.dev/openapi.json).
Screens, controllers, and existing UI device models are unchanged.

## Device operations

All routes use the origin and API prefix in `config/api_endpoints.dart`.
Each repository instance requires the actual house ID; none is hardcoded.

| Operation | Route | Response |
| --- | --- | --- |
| List house devices | `GET /api/v1/houses/{house_id}/devices` | Device array |
| List room devices | `GET /api/v1/houses/{house_id}/rooms/{room_id}/devices` | Device array |
| Read device status | `GET /api/v1/houses/{house_id}/devices/{device_id}` | Device record |
| Add device | `POST /api/v1/houses/{house_id}/devices` | Device record (201) |
| Change capability state | `PATCH /api/v1/houses/{house_id}/devices/{device_id}` | Device record (200) |

Creating a device requires supplied `id`, `name`, and `type`. `room_id` is
optional, so unassigned devices remain unassigned. Optional metadata uses
`manufacturer`, `model`, `manufactured_year`, `installed_year`, and `installer`.
The POST body can also include `capabilities`, `state`, and `status` objects.

Responses use snake_case IDs and generic capability/state/status objects.
`ApiDevice` preserves those objects and metadata. It does not assume that every
device is a light, fan, or plug, or turn missing state into a false power reading.
Mapping into the existing UI models will be a separate screen integration step.

PATCH uses an array, not a flat state object:

```json
[{"name": "speed", "value": 4}]
```

Capability names and limits come from the particular device's `capabilities`;
the server validates the command. Do not assume the old UI brightness scale
(0–1) or fan speed scale (1–3) applies to every API device. The returned record
is the backend's state; hardware command confirmation semantics are not
specified in OpenAPI. PUT changes stable metadata and is outside this scope,
as are removal and room reassignment.

## Usage when screen integration begins

```dart
final apiClient = ApiClient();
final repository = DeviceRepository(apiClient: apiClient, houseId: actualHouseId);

final devices = await repository.fetchDevices();
final roomDevices = await repository.fetchDevices(roomId: actualRoomId);
final device = await repository.fetchDeviceStatus(actualDeviceId);

// Use a capability name and value supported by this particular device.
await repository.updateDevice(id: device.id, updates: {capabilityName: value});

apiClient.close(); // Close when the owning controller/service is finished.
```

The client supports injected headers for future authentication, a request
timeout, UTF-8 JSON, and HTTP errors. Mutations are not automatically retried.
No live create or update requests were used to verify the implementation;
tests use mocked responses matching the published schema.

## Sensor readings and notifications: not published yet

The current schema has no dedicated sensor-reading or notification/alert routes.
Devices can contain sensor values in `state`/`status`, and those values are
preserved in `ApiDevice`; their field names and meaning are not documented.

`ApiEndpoints.sensorData` and `ApiEndpoints.notifications` are null. Their
repositories throw `UnsupportedError` before any request rather than contact
invented routes. The existing feed parsers are drafts only; if these endpoints
are added, verify both the URL and JSON contract before enabling them.

Draft reading fields: `id`, `deviceId`, `roomId`, `type`, `value`, `isOnline`,
optional `unit` and `recordedAt`. `value` may be null, numeric, boolean, or text.
Draft notification fields: `id`, `title`, `message`, `severity`, `createdAt`,
`isRead`, optional `deviceId` and `roomId`. Severity is `info`, `warning`, or
`critical`. Timestamps should include UTC or an offset. These draft formats
are not part of the currently published backend schema.

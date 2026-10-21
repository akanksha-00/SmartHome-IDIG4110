from fastapi import WebSocket


class ConnectionManager:
    def __init__(self):
        self.connections: dict[str, list[WebSocket]] = {}

    async def connect(
        self,
        house_id: str,
        websocket: WebSocket,
    ):
        await websocket.accept()

        if house_id not in self.connections:
            self.connections[house_id] = []

        self.connections[house_id].append(websocket)

        print(
            f"WebSocket connected: "
            f"house={house_id}, "
            f"clients={len(self.connections[house_id])}"
        )

    def disconnect(
        self,
        house_id: str,
        websocket: WebSocket,
    ):
        connections = self.connections.get(house_id)

        if connections is None:
            return

        if websocket in connections:
            connections.remove(websocket)

        if not connections:
            del self.connections[house_id]

        print(
            f"WebSocket disconnected: "
            f"house={house_id}"
        )

    async def broadcast(
        self,
        house_id: str,
        message: dict,
    ):
        connections = self.connections.get(
            house_id,
            [],
        )

        print(
            f"Broadcasting to "
            f"{len(connections)} WebSocket client(s): "
            f"house={house_id}"
        )

        disconnected = []

        for websocket in connections:
            try:
                await websocket.send_json(message)

                print(
                    f"WebSocket message sent: "
                    f"{message}"
                )

            except Exception as exc:
                print(
                    f"WebSocket send failed: "
                    f"{exc}"
                )
                disconnected.append(websocket)

        for websocket in disconnected:
            self.disconnect(
                house_id,
                websocket,
            )


manager = ConnectionManager()
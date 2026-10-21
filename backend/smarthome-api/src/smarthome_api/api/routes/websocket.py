from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from smarthome_api.websocket.manager import manager


router = APIRouter(
    prefix="/api/v1/houses",
    tags=["WebSocket"],
)


@router.websocket("/{house_id}/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    house_id: str,
):
    await manager.connect(
        house_id,
        websocket,
    )

    print(
        f"WebSocket connected: "
        f"house={house_id}"
    )

    try:
        while True:
            await websocket.receive_text()

    except WebSocketDisconnect:
        manager.disconnect(
            house_id,
            websocket,
        )

        print(
            f"WebSocket disconnected: "
            f"house={house_id}"
        )
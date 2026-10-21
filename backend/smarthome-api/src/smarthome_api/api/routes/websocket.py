import asyncio
import json

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.security import HTTPAuthorizationCredentials

from smarthome_api.auth import get_current_user
from smarthome_api.services.house_service import get_house
from smarthome_api.services.user_service import get_or_create_user
from smarthome_api.websocket.manager import manager


router = APIRouter(
    prefix="/api/v1/houses",
    tags=["WebSocket"],
)

AUTH_TIMEOUT_SECONDS = 10


@router.websocket("/{house_id}/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    house_id: str,
):
    # Accept the WebSocket connection before receiving the auth message.
    await websocket.accept()

    registered = False

    try:
        # 1. Wait for the authentication message.
        print(f"WebSocket waiting for auth: house={house_id}")

        try:
            message = await asyncio.wait_for(
                websocket.receive_text(),
                timeout=AUTH_TIMEOUT_SECONDS,
            )
        except asyncio.TimeoutError:
            print(f"WebSocket authentication timeout: house={house_id}")

            await websocket.close(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="Authentication timeout",
            )
            return

        # 2. Parse the authentication message.
        try:
            auth_message = json.loads(message)
        except json.JSONDecodeError:
            print(f"WebSocket received invalid JSON: house={house_id}")

            await websocket.close(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="Invalid authentication message",
            )
            return

        # Log the message structure without exposing the access token.
        print(
            "WebSocket auth message received:",
            f"type={auth_message.get('type') if isinstance(auth_message, dict) else 'invalid'}",
            f"has_token={bool(auth_message.get('token')) if isinstance(auth_message, dict) else False}",
        )

        if (
            not isinstance(auth_message, dict)
            or auth_message.get("type") != "auth"
            or not isinstance(auth_message.get("token"), str)
            or not auth_message["token"]
        ):
            print(f"WebSocket authentication message invalid: house={house_id}")

            await websocket.close(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="Authentication required",
            )
            return

        # 3. Validate the Supabase access token.
        credentials = HTTPAuthorizationCredentials(
            scheme="Bearer",
            credentials=auth_message["token"],
        )

        try:
            claims = get_current_user(credentials)
        except HTTPException:
            print(f"WebSocket JWT validation failed: house={house_id}")

            await websocket.close(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="Authentication failed",
            )
            return

        # 4. Retrieve the application user profile.
        # The JWT subject identifies the Supabase user.
        user_id = claims.get("sub")

        if not user_id:
            print(f"WebSocket JWT has no subject: house={house_id}")

            await websocket.close(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="Invalid user identity",
            )
            return

        current_user = get_or_create_user(user_id)

        if current_user is None:
            print(f"WebSocket user profile unavailable: user={user_id}")

            await websocket.close(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="User profile unavailable",
            )
            return

        # 5. Verify that the user can access this house.
        if current_user.get("role") == "platform_admin":
            house = get_house(house_id)
        else:
            house = get_house(
                house_id,
                owner_id=current_user["id"],
            )

        if house is None:
            print(
                f"WebSocket house access denied: "
                f"user={current_user['id']}, house={house_id}"
            )

            await websocket.close(
                code=status.WS_1008_POLICY_VIOLATION,
                reason="House access denied",
            )
            return

        # 6. Register the connection.
        # The socket has already been accepted, so avoid accepting it twice.
        await manager.connect(
            house_id,
            websocket,
            accept=False,
        )
        registered = True

        print(
            f"WebSocket authenticated: "
            f"user={current_user['id']}, house={house_id}"
        )

        # 7. Keep the connection open until the client disconnects.
        while True:
            await websocket.receive_text()

    except WebSocketDisconnect:
        print(f"WebSocket client disconnected: house={house_id}")

    except Exception:
        # Log unexpected errors for debugging without logging credentials.
        import logging

        logging.getLogger(__name__).exception(
            "Unexpected WebSocket error: house=%s",
            house_id,
        )

        try:
            await websocket.close(
                code=status.WS_1011_INTERNAL_ERROR,
                reason="Internal server error",
            )
        except Exception:
            pass

    finally:
        # Only unregister connections that were successfully registered.
        if registered:
            manager.disconnect(
                house_id,
                websocket,
            )
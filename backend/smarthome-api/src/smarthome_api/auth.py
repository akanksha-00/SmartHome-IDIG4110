from functools import lru_cache
from smarthome_api.services.user_service import get_user
import httpx
import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from smarthome_api.services.user_service import get_or_create_user

from smarthome_api.config import settings


bearer_scheme = HTTPBearer()

SUPABASE_ISSUER = f"{settings.supabase_url}/auth/v1"


@lru_cache(maxsize=1)
def get_jwks() -> dict:
    """Retrieve Supabase's public JWT signing keys."""

    response = httpx.get(
        f"{settings.supabase_url}/auth/v1/.well-known/jwks.json",
        timeout=10.0,
    )
    response.raise_for_status()

    return response.json()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> dict:
    """Verify a Supabase access token and return its claims."""

    token = credentials.credentials

    try:
        header = jwt.get_unverified_header(token)

        # Supabase currently uses ES256 for this project.
        if header.get("alg") != "ES256":
            raise HTTPException(
                status_code=401,
                detail="Unsupported token algorithm",
            )

        key_id = header.get("kid")

        if not key_id:
            raise HTTPException(
                status_code=401,
                detail="Missing token signing key ID",
            )

        jwks = get_jwks()

        signing_key = next(
            (
                key
                for key in jwks.get("keys", [])
                if key.get("kid") == key_id
            ),
            None,
        )

        if signing_key is None:
            raise HTTPException(
                status_code=401,
                detail="Unknown token signing key",
            )

        public_key = jwt.PyJWK.from_dict(signing_key).key

        claims = jwt.decode(
            token,
            public_key,
            algorithms=["ES256"],
            audience="authenticated",
            issuer=SUPABASE_ISSUER,
        )

        user_id = claims.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=401,
                detail="Token has no user ID",
            )

        return claims

    except HTTPException:
        raise

    except (jwt.PyJWTError, httpx.HTTPError, ValueError, KeyError):
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired access token",
        ) from None

def get_current_user_id(
    current_user: dict = Depends(get_current_user),
) -> str:
    """Return the authenticated user's UUID."""
    return current_user["sub"]


def get_current_app_user(
    user_id: str = Depends(get_current_user_id),
) -> dict:
    """Return the authenticated user's application profile."""
    user = get_or_create_user(user_id)

    if user is None:
        raise HTTPException(
            status_code=500,
            detail="Could not create user profile",
        )

    return user

def require_platform_admin(
    current_user: dict = Depends(get_current_app_user),
) -> dict:
    """Allow access only to platform administrators."""
    if current_user.get("role") != "platform_admin":
        raise HTTPException(
            status_code=403,
            detail="Platform administrator privileges required",
        )

    return current_user
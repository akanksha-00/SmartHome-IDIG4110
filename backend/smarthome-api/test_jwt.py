import getpass

from smarthome_api.auth import get_current_user
from fastapi.security import HTTPAuthorizationCredentials

token = getpass.getpass("Paste your Supabase access token: ")

credentials = HTTPAuthorizationCredentials(
    scheme="Bearer",
    credentials=token,
)

try:
    claims = get_current_user(credentials)

    print("JWT verification successful!")
    print("User ID:", claims["sub"])
    print("Issuer:", claims["iss"])
    print("Audience:", claims["aud"])

except Exception as exc:
    print("JWT verification failed:", type(exc).__name__, str(exc))
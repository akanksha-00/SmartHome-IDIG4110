import getpass
import httpx

SUPABASE_URL = "https://yrameppdhqbfturciptc.supabase.co"

api_key = getpass.getpass("Supabase publishable key: ")
email = input("Test user email: ")
password = getpass.getpass("Test user password: ")

response = httpx.post(
    f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
    headers={
        "apikey": api_key,
        "Content-Type": "application/json",
    },
    json={
        "email": email,
        "password": password,
    },
    timeout=15,
)

if response.is_success:
    data = response.json()
    print("\nLogin successful.")
    print("User ID:", data["user"]["id"])
    print("\nAccess token (keep private):\n")
    print(data["access_token"])
else:
    print("Login failed:", response.status_code)
    print(response.text)
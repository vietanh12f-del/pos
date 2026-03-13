
import jwt, time, sys
from pathlib import Path

TEAM_ID = "CM6SD7QW9K"
KEY_ID = "ZWYWQ7788A"        # ví dụ: ZWYWQ7788A
CLIENT_ID = "com.smartkiot.smartkiot" # ví dụ: com.yourcompany.web
PRIVATE_KEY_PATH = "AuthKey_ZWYWQ7788A.p8"

iat = int(time.time())
# Apple cho phép tối đa 6 tháng; ở đây đặt ~6 tháng (15552000s)
exp = iat + 15552000

headers = { "alg": "ES256", "kid": KEY_ID, "typ": "JWT" }
payload = {
    "iss": TEAM_ID,
    "iat": iat,
    "exp": exp,
    "aud": "https://appleid.apple.com",
    "sub": CLIENT_ID
}

key = Path(PRIVATE_KEY_PATH).read_text()
token = jwt.encode(payload, key, algorithm="ES256", headers=headers)
# PyJWT >= 2 trả về str; nếu là bytes thì decode ra
print(token if isinstance(token, str) else token.decode("utf-8"))

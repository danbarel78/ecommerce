"""Test fixtures.

Runs the API against in-memory SQLite (no Postgres/Docker needed) and verifies JWTs
against a locally-generated RS256 key pair (no live Cognito). Env vars are set BEFORE
importing the app so cached Settings pick them up."""

import os
from datetime import UTC, datetime, timedelta

# --- Configure the app for tests (must precede app import) ---
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

_private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_private_pem = _private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
).decode()
_public_pem = (
    _private_key.public_key()
    .public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    .decode()
)

os.environ["PRODUCT_API_DATABASE_URL"] = "sqlite+aiosqlite:///:memory:"
os.environ["PRODUCT_API_JWKS_URL"] = ""  # local mode
os.environ["PRODUCT_API_JWT_ISSUER"] = "https://test-issuer.local"
os.environ["PRODUCT_API_JWT_AUDIENCE"] = "ecommerce-api"
os.environ["PRODUCT_API_AUTH_LOCAL_PUBLIC_KEY"] = _public_pem
os.environ["PRODUCT_API_RATE_LIMIT"] = "5/minute"

import pytest  # noqa: E402
import pytest_asyncio  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from jose import jwk, jwt  # noqa: E402

from product_service.db import Base, engine  # noqa: E402
from product_service.main import app  # noqa: E402
from product_service.ratelimit import limiter  # noqa: E402

ISSUER = "https://test-issuer.local"
AUDIENCE = "ecommerce-api"

# Expose the private key + a JWKS document so JWKS-mode auth can be exercised offline.
PRIVATE_PEM = _private_pem
JWKS_KID = "test-key-1"


def build_jwks() -> dict:
    """Return a JWKS document containing the test public key (RS256)."""
    key_obj = jwk.construct(_public_pem, algorithm="RS256")
    entry = key_obj.to_dict()
    entry.update({"kid": JWKS_KID, "use": "sig", "alg": "RS256"})
    return {"keys": [entry]}


def make_token(
    *,
    scope: str = "products:write",
    expired: bool = False,
    audience: str = AUDIENCE,
    kid: str | None = None,
) -> str:
    now = datetime.now(UTC)
    exp = now - timedelta(minutes=5) if expired else now + timedelta(minutes=30)
    claims = {
        "sub": "test-user",
        "iss": ISSUER,
        "aud": audience,
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
        "scope": scope,
    }
    headers = {"kid": kid} if kid else None
    return jwt.encode(claims, _private_pem, algorithm="RS256", headers=headers)


@pytest.fixture
def write_token() -> str:
    return make_token(scope="products:write")


@pytest.fixture
def read_only_token() -> str:
    return make_token(scope="products:read")


@pytest.fixture
def expired_token() -> str:
    return make_token(expired=True)


@pytest.fixture(autouse=True)
def _disable_rate_limit():
    """Rate limiting off by default so CRUD tests aren't throttled; the rate-limit
    test re-enables it explicitly."""
    limiter.enabled = False
    yield
    limiter.enabled = True


@pytest_asyncio.fixture(autouse=True)
async def _reset_db():
    """Fresh schema per test (StaticPool keeps the in-memory DB alive across sessions)."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield


@pytest_asyncio.fixture
async def client() -> AsyncClient:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def sample_product() -> dict:
    return {
        "sku": "SKU-1",
        "title": "Wireless Mouse",
        "description": "Ergonomic 2.4GHz mouse",
        "price_cents": 2999,
        "currency": "USD",
        "stock": 50,
    }

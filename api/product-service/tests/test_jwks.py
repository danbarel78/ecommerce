"""JWKS-mode auth tests — exercise the async fetch + TTL cache and the misconfig path.

These run offline: the JWKS document is built from the test key pair and the async HTTP
client is monkeypatched so no network call is made.
"""

from http import HTTPStatus

import pytest
from fastapi import HTTPException

from product_service import auth
from product_service.config import Settings
from tests.conftest import AUDIENCE, ISSUER, JWKS_KID, build_jwks, make_token


class _FakeResponse:
    def __init__(self, payload: dict) -> None:
        self._payload = payload

    def raise_for_status(self) -> None:
        return None

    def json(self) -> dict:
        return self._payload


class _FakeAsyncClient:
    """Stand-in for httpx.AsyncClient that returns a fixed JWKS and counts calls."""

    calls = 0

    def __init__(self, *args: object, **kwargs: object) -> None:
        pass

    async def __aenter__(self) -> "_FakeAsyncClient":
        return self

    async def __aexit__(self, *args: object) -> None:
        return None

    async def get(self, _url: str) -> _FakeResponse:
        type(self).calls += 1
        return _FakeResponse(build_jwks())


@pytest.fixture(autouse=True)
def _reset_jwks_state(monkeypatch: pytest.MonkeyPatch) -> None:
    auth._jwks_cache.clear()
    _FakeAsyncClient.calls = 0
    monkeypatch.setattr(auth.httpx, "AsyncClient", _FakeAsyncClient)


def _jwks_settings() -> Settings:
    return Settings(
        jwks_url="https://issuer.local/.well-known/jwks.json",
        jwt_issuer=ISSUER,
        jwt_audience=AUDIENCE,
        auth_local_public_key="",
    )


async def test_jwks_mode_accepts_valid_token() -> None:
    settings = _jwks_settings()
    token = make_token(scope="products:write", kid=JWKS_KID)
    claims = await auth._decode(token, settings)
    assert claims["scope"] == "products:write"


async def test_jwks_document_is_cached() -> None:
    settings = _jwks_settings()
    token = make_token(scope="products:read", kid=JWKS_KID)

    await auth._decode(token, settings)
    await auth._decode(token, settings)

    # Second decode should reuse the cached JWKS, not re-fetch.
    assert _FakeAsyncClient.calls == 1


async def test_missing_auth_config_is_server_error() -> None:
    settings = Settings(jwks_url="", auth_local_public_key="")
    with pytest.raises(HTTPException) as exc_info:
        await auth._resolve_key(settings)
    assert exc_info.value.status_code == HTTPStatus.INTERNAL_SERVER_ERROR

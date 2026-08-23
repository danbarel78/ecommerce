"""JWT Bearer authentication (OAuth2), verified against Cognito JWKS (ARCHITECTURE.md §4.3.2).

Two modes:
  * JWKS mode (real):   fetch Cognito's public keys and verify RS256 signatures + claims.
  * Local mode (tests): verify against a configured PEM public key (no network).
Write endpoints additionally require the `products:write` scope.
"""

from __future__ import annotations

import logging
import time
from typing import Any

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import jwt
from jose.exceptions import JWTError

from product_service.config import Settings, get_settings

logger = logging.getLogger(__name__)

bearer_scheme = HTTPBearer(auto_error=False)

# JWKS documents are cached with a bounded TTL so rotated Cognito signing keys are
# picked up automatically (a plain lru_cache would serve the first key set forever).
_JWKS_TIMEOUT_S = 5.0
_JWKS_CACHE_TTL_S = 3600.0

_jwks_cache: dict[str, tuple[float, dict[str, Any]]] = {}


async def _fetch_jwks(jwks_url: str) -> dict[str, Any]:
    """Return the JWKS document for ``jwks_url``, refreshing when the cache entry is stale.

    Uses an async HTTP client so the event loop is not blocked, and a TTL cache so key
    rotation is honoured without a process restart.
    """
    cached = _jwks_cache.get(jwks_url)
    now = time.monotonic()
    if cached is not None and now - cached[0] < _JWKS_CACHE_TTL_S:
        return cached[1]

    async with httpx.AsyncClient(timeout=_JWKS_TIMEOUT_S) as client:
        resp = await client.get(jwks_url)
    resp.raise_for_status()
    document: dict[str, Any] = resp.json()
    _jwks_cache[jwks_url] = (now, document)
    return document


def _credentials_error(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


async def _resolve_key(settings: Settings) -> str | dict[str, Any]:
    if settings.jwks_url:
        return await _fetch_jwks(settings.jwks_url)
    # Local mode: verify against the configured PEM public key. A missing key is a
    # deployment misconfiguration, not a client credential failure.
    if not settings.auth_local_public_key:
        logger.error("Auth is not configured: no JWKS URL and no local public key set")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication is not configured",
        )
    return settings.auth_local_public_key


async def _decode(token: str, settings: Settings) -> dict[str, Any]:
    key = await _resolve_key(settings)
    options = {"verify_aud": bool(settings.jwt_audience)}
    try:
        claims: dict[str, Any] = jwt.decode(
            token,
            key,
            algorithms=settings.jwt_algorithms,
            audience=settings.jwt_audience or None,
            issuer=settings.jwt_issuer or None,
            options=options,
        )
    except JWTError as exc:
        raise _credentials_error(f"Invalid token: {exc}") from exc
    return claims


async def get_current_claims(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Validate the bearer token and return its verified claims."""
    if credentials is None or not credentials.credentials:
        raise _credentials_error("Missing bearer token")
    return await _decode(credentials.credentials, settings)


def _token_scopes(claims: dict[str, Any]) -> set[str]:
    # Cognito puts space-delimited scopes in `scope`; some IdPs use a `scp` list.
    raw = claims.get("scope") or claims.get("scp") or ""
    if isinstance(raw, str):
        return set(raw.split())
    return set(raw)


async def require_write_scope(
    claims: dict[str, Any] = Depends(get_current_claims),
    settings: Settings = Depends(get_settings),
) -> dict[str, Any]:
    """Authorize a write: the token must carry the configured write scope."""
    if settings.required_write_scope not in _token_scopes(claims):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing required scope: {settings.required_write_scope}",
        )
    return claims

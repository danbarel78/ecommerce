# Product Management API

The Catalog microservice's **product CRUD** surface for the cloud-native e-commerce
platform (ARCHITECTURE.md §4.2). FastAPI + async SQLAlchemy, JWT Bearer auth against
Cognito JWKS (§4.3.2), per-IP rate limiting, and a full pytest suite.

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET` | `/products` | public | List products (paginated, `q` title filter) |
| `GET` | `/products/{id}` | public | Fetch one product (404 if missing) |
| `POST` | `/products` | `products:write` | Create a product (409 on duplicate SKU) |
| `PUT` | `/products/{id}` | `products:write` | Partial update |
| `DELETE` | `/products/{id}` | `products:write` | Delete (204) |
| `GET` | `/healthz` | public | Liveness/readiness probe |

## Layout

```
src/product_service/
  main.py       FastAPI app + routes + lifespan (schema init)
  config.py     env/Secrets-Manager settings (PRODUCT_API_ prefix)
  db.py         async engine/session; SQLite (tests) or Aurora PostgreSQL (real)
  models.py     Product ORM model
  schemas.py    Pydantic request/response models with validation
  crud.py       data-access layer (pure DB ops)
  auth.py       JWT verify vs Cognito JWKS (async fetch + TTL cache, + local-key mode); scope check
  ratelimit.py  slowapi token-bucket per client IP
  deps.py       shared deps (fetch-or-404)
tests/          pytest: CRUD, auth boundaries, JWKS mode, rate-limit, pagination
```

Standard team `src/` layout; the package installs as `product_service`.

## Configuration

All settings use the `PRODUCT_API_` env prefix (see `.env.example`). Key ones:

- `PRODUCT_API_DATABASE_URL` — async SQLAlchemy URL. Default in-memory SQLite; real
  deployments use `postgresql+asyncpg://...@<aurora-proxy-endpoint>/ecommerce`.
- `PRODUCT_API_JWKS_URL` / `PRODUCT_API_JWT_ISSUER` — **REQUIRES REAL VALUE**: the Cognito
  user-pool JWKS endpoint + issuer. When `JWKS_URL` is empty the API runs in local mode and
  verifies tokens against `PRODUCT_API_AUTH_LOCAL_PUBLIC_KEY` (used by the test suite).
- `PRODUCT_API_RATE_LIMIT` — slowapi limit, e.g. `100/minute`. This is the app-tier defense;
  the edge-tier defense is the AWS WAF rate rule (`infra/modules/security`).

## Run locally

```bash
uv sync --all-extras                          # install from uv.lock
uv run uvicorn product_service.main:app --reload   # http://127.0.0.1:8000/docs
```

## Test

```bash
uv run pytest --cov=product_service --cov-report=term-missing   # 25 tests, ~91% coverage
```

Tests run entirely offline: in-memory SQLite + a locally-generated RS256 key pair for JWTs,
exercising both local-key and JWKS verification modes (no Docker, no live Cognito/Aurora).

## Quality gate

```bash
uv run ruff check src tests && uv run ruff format --check src tests
uv run mypy src && uv run pyright src
```

## Container

```bash
docker build -t product-service .
docker run -p 8000:8000 product-service
curl localhost:8000/healthz
```

Multi-stage build (deps installed into an isolated venv), runs as a non-root user.

## Auth quick reference

Write calls need `Authorization: Bearer <jwt>` where the token carries the
`products:write` scope (Cognito `scope` claim). Reads are public and CDN-cacheable.
- missing/invalid/expired token → `401`
- valid token without the write scope → `403`

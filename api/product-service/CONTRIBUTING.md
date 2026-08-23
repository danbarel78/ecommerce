# Contributing — product-service

This service follows the team's **DevOps Python Project Guidelines**
([Confluence page 802293223](https://pdc-amat-prod.atlassian.net/wiki/spaces/NNGA/pages/802293223/DevOps+Python+Project+Guidelines)).
Read that page before making non-trivial changes; the rules below mirror it.

## Development setup

```bash
# uv is the dependency manager (https://astral.sh/uv)
curl -LsSf https://astral.sh/uv/install.sh | sh

uv sync --all-extras            # install runtime + dev deps from uv.lock
uv run pre-commit install       # enable the git hooks
```

Layout: source lives under `src/product_service/`; tests mirror it under `tests/`.

## Testing

```bash
uv run pytest                                   # full suite (strict markers, -ra -q)
uv run pytest --cov=product_service --cov-report=term-missing   # with coverage
```

Coverage target: **80%+ overall**, 100% on critical paths (auth + CRUD). Tests run
offline — in-memory SQLite plus a locally-generated RS256 key pair for JWTs (JWKS and
local modes are both exercised); no Docker, Cognito, or Aurora required.

## Code quality

All four tools must pass before merge (also enforced by pre-commit + CI):

```bash
uv run ruff check src tests        # lint
uv run ruff format src tests       # format
uv run mypy src                    # strict type check
uv run pyright src                 # strict type check
```

Ruff config is the team-canonical rule set (see `pyproject.toml`). Mypy and Pyright both
run in `strict` mode.

## Building

Cloud/container workload → **wheel + Docker** (per the guidelines' build-decision matrix):

```bash
uv build                           # wheel into dist/
docker build -t product-service .  # container image (non-root, multi-stage)
```

## CI/CD

Two Azure pipelines under `.azure_pipelines/`:

- `pr_validation.yml` — pre-commit, quality gate (lint/type/test), and build verification on every PR.
- `build_and_publish.yml` — version determination, build, and registry publish on merge to `main`.

Reusable step templates live in `.azure_pipelines/templates/`.

## Version management

SemVer `MAJOR.MINOR.PATCH`. `base_version.json` holds `{major, minor}`; CI appends
`Build.BuildId` as the patch. `src/product_service/__init__.py` carries `__version__`
(surfaced by the app and the built wheel).

## Pull request process

1. Branch from `main`; keep changes focused.
2. Ensure `uv run pre-commit run --all-files` and the full test suite pass locally.
3. Open a PR to `main`; the `pr_validation` pipeline must be green.
4. Squash-merge once approved.

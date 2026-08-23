"""Rate-limit test — verifies slowapi returns 429 once the per-IP threshold is exceeded.

The autouse fixture disables the limiter for other tests; here we re-enable it. The
configured limit in the test env is 5/minute."""

from http import HTTPStatus

import pytest

from product_service.ratelimit import limiter


@pytest.fixture(autouse=True)
def _enable_rate_limit():
    limiter.enabled = True
    limiter.reset()
    yield
    limiter.enabled = False


async def test_rate_limit_returns_429(client):
    # Public GET is cheap and unauthenticated — good target for hammering.
    statuses = [(await client.get("/products")).status_code for _ in range(8)]

    assert HTTPStatus.OK in statuses
    assert HTTPStatus.TOO_MANY_REQUESTS in statuses, f"expected a 429 after the limit, got {statuses}"

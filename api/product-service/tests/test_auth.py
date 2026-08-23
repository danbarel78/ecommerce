"""Auth boundary tests: missing / expired / wrong-scope / wrong-audience tokens."""

from http import HTTPStatus

from tests.conftest import make_token


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def test_create_requires_token(client, sample_product):
    resp = await client.post("/products", json=sample_product)
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


async def test_create_rejects_expired_token(client, sample_product, expired_token):
    resp = await client.post("/products", json=sample_product, headers=_auth(expired_token))
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


async def test_create_rejects_missing_scope(client, sample_product, read_only_token):
    resp = await client.post("/products", json=sample_product, headers=_auth(read_only_token))
    assert resp.status_code == HTTPStatus.FORBIDDEN


async def test_wrong_audience_rejected(client, sample_product):
    token = make_token(scope="products:write", audience="some-other-api")
    resp = await client.post("/products", json=sample_product, headers=_auth(token))
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


async def test_reads_are_public(client, write_token, sample_product):
    # create with auth
    await client.post("/products", json=sample_product, headers=_auth(write_token))
    # list without auth works
    assert (await client.get("/products")).status_code == HTTPStatus.OK


async def test_update_and_delete_require_scope(client, write_token, read_only_token, sample_product):
    created = await client.post("/products", json=sample_product, headers=_auth(write_token))
    pid = created.json()["id"]

    upd = await client.put(f"/products/{pid}", json={"stock": 1}, headers=_auth(read_only_token))
    assert upd.status_code == HTTPStatus.FORBIDDEN

    dele = await client.delete(f"/products/{pid}", headers=_auth(read_only_token))
    assert dele.status_code == HTTPStatus.FORBIDDEN

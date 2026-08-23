"""CRUD + validation + pagination tests."""

from http import HTTPStatus

import pytest


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


async def test_healthz(client):
    resp = await client.get("/healthz")
    assert resp.status_code == HTTPStatus.OK
    assert resp.json()["status"] == "ok"


async def test_create_product(client, write_token, sample_product):
    resp = await client.post("/products", json=sample_product, headers=_auth(write_token))
    assert resp.status_code == HTTPStatus.CREATED
    body = resp.json()
    assert body["sku"] == "SKU-1"
    assert body["price_cents"] == sample_product["price_cents"]
    assert body.get("id")


async def test_get_product(client, write_token, sample_product):
    created = await client.post("/products", json=sample_product, headers=_auth(write_token))
    pid = created.json()["id"]

    resp = await client.get(f"/products/{pid}")
    assert resp.status_code == HTTPStatus.OK
    assert resp.json()["title"] == "Wireless Mouse"


async def test_get_product_404(client):
    resp = await client.get("/products/does-not-exist")
    assert resp.status_code == HTTPStatus.NOT_FOUND


async def test_update_product(client, write_token, sample_product):
    created = await client.post("/products", json=sample_product, headers=_auth(write_token))
    pid = created.json()["id"]

    new_price = 1999
    resp = await client.put(f"/products/{pid}", json={"price_cents": new_price}, headers=_auth(write_token))
    assert resp.status_code == HTTPStatus.OK
    assert resp.json()["price_cents"] == new_price
    # unchanged fields persist
    assert resp.json()["title"] == "Wireless Mouse"


async def test_update_product_404(client, write_token):
    resp = await client.put("/products/missing", json={"price_cents": 100}, headers=_auth(write_token))
    assert resp.status_code == HTTPStatus.NOT_FOUND


async def test_delete_product(client, write_token, sample_product):
    created = await client.post("/products", json=sample_product, headers=_auth(write_token))
    pid = created.json()["id"]

    resp = await client.delete(f"/products/{pid}", headers=_auth(write_token))
    assert resp.status_code == HTTPStatus.NO_CONTENT

    # gone
    assert (await client.get(f"/products/{pid}")).status_code == HTTPStatus.NOT_FOUND


async def test_delete_product_404(client, write_token):
    resp = await client.delete("/products/missing", headers=_auth(write_token))
    assert resp.status_code == HTTPStatus.NOT_FOUND


async def test_duplicate_sku_conflict(client, write_token, sample_product):
    await client.post("/products", json=sample_product, headers=_auth(write_token))
    resp = await client.post("/products", json=sample_product, headers=_auth(write_token))
    assert resp.status_code == HTTPStatus.CONFLICT


@pytest.mark.parametrize(
    "bad_field",
    [
        {"price_cents": -1},
        {"sku": ""},
        {"title": ""},
        {"stock": -5},
        {"currency": "US"},  # too short
    ],
)
async def test_create_validation_error(client, write_token, sample_product, bad_field):
    payload = {**sample_product, **bad_field}
    resp = await client.post("/products", json=payload, headers=_auth(write_token))
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


async def test_list_pagination_and_filter(client, write_token):
    total_created = 5
    page_size = 2
    for i in range(total_created):
        await client.post(
            "/products",
            json={"sku": f"SKU-{i}", "title": f"Item {i}", "price_cents": 100 * i},
            headers=_auth(write_token),
        )

    # pagination
    page = await client.get("/products", params={"limit": page_size, "offset": 0})
    assert page.status_code == HTTPStatus.OK
    body = page.json()
    assert body["total"] == total_created
    assert len(body["items"]) == page_size
    assert body["limit"] == page_size

    # title filter
    filtered = await client.get("/products", params={"q": "Item 3"})
    assert filtered.json()["total"] == 1
    assert filtered.json()["items"][0]["title"] == "Item 3"

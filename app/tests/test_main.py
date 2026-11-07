from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_returns_42():
    response = client.get("/")

    assert response.status_code == 200
    assert response.text == "42"


def test_liveness():
    response = client.get("/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "alive"}


def test_readiness():
    response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_unknown_endpoint():
    response = client.get("/unknown")

    assert response.status_code == 404
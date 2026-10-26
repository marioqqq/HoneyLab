import os

import httpx

PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "http://prometheus:9090")


async def _request(path: str, params: dict, timeout: int, error: str):
    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.get(f"{PROMETHEUS_URL}{path}", params=params)
        response.raise_for_status()
        data = response.json()

    if data["status"] != "success":
        raise RuntimeError(data.get("error", error))

    return data["data"]["result"]


async def query(promql: str):
    return await _request("/api/v1/query", {"query": promql}, 10, "Prometheus query failed")


async def query_range(promql: str, start: float, end: float, step: str):
    return await _request(
        "/api/v1/query_range",
        {"query": promql, "start": start, "end": end, "step": step},
        30,
        "Prometheus range query failed",
    )
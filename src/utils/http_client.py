from __future__ import annotations

from typing import Dict, Optional

import requests

from constants import DEFAULT_HEADERS, HTTP_TIMEOUT
from errors import ExtractionError, HttpRequestError
from utils.parsing import extractServerJarUrl


def httpGet(url: str, headers: Optional[Dict[str, str]] = None) -> requests.Response:
    try:
        response = requests.get(
            url,
            headers=headers or DEFAULT_HEADERS,
            timeout=HTTP_TIMEOUT,
            allow_redirects=True,
        )
    except requests.RequestException as exc:
        raise HttpRequestError(f"Request to '{url}' failed: {exc}") from exc

    if response.status_code >= 400:
        raise HttpRequestError(f"Request to '{url}' returned HTTP {response.status_code}")

    return response


def testHttpConnectivity() -> None:
    testUrl = "https://httpbin.org/get"
    httpGet(testUrl)


def fetchServerJarUrl(version: str) -> str:
    downloadPageUrl = f"https://mcversions.net/download/{version}"
    response = httpGet(downloadPageUrl)
    serverJarUrl = extractServerJarUrl(response.text)
    if serverJarUrl is None:
        raise ExtractionError("Unable to locate server.jar URL in download page")
    return serverJarUrl


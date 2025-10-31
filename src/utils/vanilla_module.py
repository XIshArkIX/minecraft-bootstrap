import re
import requests
from constants import DEFAULT_HEADERS, HTTP_TIMEOUT
from errors import DownloadError, ExtractionError, InstallationError
from typing import Optional
from pathlib import Path


MC_VERSIONS_NET_URL = "https://mcversions.net/download/"
SERVER_JAR_URL_PATTERN = r"https://piston-data\.mojang\.com/v1/objects/[0-9a-f]+/server\.jar"


def extractServerJarUrl(content: str) -> Optional[str]:
    match = re.search(SERVER_JAR_URL_PATTERN, content)
    if not match:
        return None
    return match.group(0)


def fetchServerJarUrl(version: str) -> Optional[str]:
    downloadPageUrl = f"{MC_VERSIONS_NET_URL}{version}"
    print(
        f"Fetching server jar URL from {downloadPageUrl}\t", end="", flush=True)
    response = requests.get(downloadPageUrl, headers=DEFAULT_HEADERS,
                            timeout=HTTP_TIMEOUT, allow_redirects=True)
    serverJarUrl = extractServerJarUrl(response.text)
    if serverJarUrl is None:
        raise ExtractionError(
            "Unable to locate server.jar URL in download page")
    print(f"OK")
    return serverJarUrl


def downloadServerJar(url: str, destination: Path) -> bool:
    print(f"Downloading server jar from {url}\t", end="", flush=True)
    response = requests.get(url, headers=DEFAULT_HEADERS,
                            timeout=HTTP_TIMEOUT, allow_redirects=True)
    if response.status_code != 200:
        raise DownloadError(
            f"Failed to download server jar from {url}: {response.status_code}")
    with open(destination, "wb") as file:
        file.write(response.content)
    print(f"OK")
    return True


def vanillaBootstrap(version: str, destination: Path) -> bool:
    print(f"Bootstrapping vanilla server {version}", flush=True)
    serverJarUrl = fetchServerJarUrl(version)
    if serverJarUrl is None:
        raise InstallationError(
            "Unable to locate server.jar URL in download page")
    try:
        downloadServerJar(serverJarUrl, destination / "server.jar")
    except DownloadError as exc:
        raise InstallationError(
            f"Failed to download server jar: {exc}") from exc
    except ExtractionError as exc:
        raise InstallationError(
            f"Failed to extract server jar: {exc}") from exc
    print(f"Vanilla server {version} bootstrapped successfully")
    return True

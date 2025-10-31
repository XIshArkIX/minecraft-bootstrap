import requests
from constants import DEFAULT_HEADERS, HTTP_TIMEOUT
from errors import DownloadError, ExtractionError, InstallationError
from typing import Optional
import zipfile
import io
from pathlib import Path


def downloadServerPack(url: str) -> Optional[bytes]:
    print(f"Downloading server pack from {url}\t", end="", flush=True)
    response = requests.get(url, headers=DEFAULT_HEADERS,
                            timeout=HTTP_TIMEOUT, allow_redirects=True)
    if response.status_code != 200:
        raise DownloadError(
            f"Failed to download server pack from {url}: {response.status_code}")
    print(f"OK")
    return response.content


def extractServerPack(data: bytes, destination: Path) -> bool:
    print(f"Extracting server pack to {destination}\t", end="", flush=True)
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            archive.extractall(path=destination)
        print(f"OK")
        return True
    except zipfile.BadZipFile:
        raise ExtractionError(
            "Downloaded server pack is corrupted or not a valid ZIP file")
    except OSError:
        raise ExtractionError(
            "Failed to extract server pack")


def manualBootstrap(url: str, destination: Path) -> bool:
    print(f"Bootstrapping manual server from {url}", flush=True)
    data = downloadServerPack(url)
    if data is None:
        raise DownloadError(
            f"Failed to download server pack from {url}")
    try:
        extractServerPack(data, destination)
    except ExtractionError as exc:
        raise InstallationError(
            f"Failed to install server pack: {exc}") from exc
    print(f"Manual server bootstrapped successfully")
    return True

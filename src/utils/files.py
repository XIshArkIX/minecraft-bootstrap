from __future__ import annotations

import io
from pathlib import Path
import zipfile

import requests

from constants import DEFAULT_HEADERS, DOWNLOAD_BUFFER_SIZE, HTTP_TIMEOUT
from errors import DownloadError, InvalidModpackFormatError, ModpackExtractionError


def downloadFile(url: str, destination: Path) -> None:
    try:
        with requests.get(
            url,
            headers=DEFAULT_HEADERS,
            timeout=HTTP_TIMEOUT,
            stream=True,
            allow_redirects=True,
        ) as response:
            if response.status_code >= 400:
                raise DownloadError(f"Download from '{url}' returned HTTP {response.status_code}")

            destination.parent.mkdir(parents=True, exist_ok=True)
            with destination.open("wb") as fileHandle:
                for chunk in response.iter_content(chunk_size=DOWNLOAD_BUFFER_SIZE):
                    if chunk:
                        fileHandle.write(chunk)
    except requests.RequestException as exc:
        raise DownloadError(f"Failed to download '{url}': {exc}") from exc


def createEulaFile(workingDir: Path) -> Path:
    eulaPath = workingDir / "eula.txt"
    eulaPath.write_text("eula=true\n", encoding="utf-8")
    return eulaPath


def extractZipArchive(data: bytes, destination: Path) -> None:
    if len(data) < 4 or data[:2] != b"PK":
        raise InvalidModpackFormatError("Downloaded modpack data is not a ZIP archive (missing PK signature)")

    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            archive.extractall(destination)
    except zipfile.BadZipFile as exc:
        raise InvalidModpackFormatError("Downloaded modpack archive is corrupted or not a valid ZIP file") from exc
    except OSError as exc:
        raise ModpackExtractionError(f"Failed to extract modpack archive: {exc}") from exc




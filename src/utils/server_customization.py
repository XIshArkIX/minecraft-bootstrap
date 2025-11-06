from pathlib import Path
from typing import Dict
from PIL import Image
import requests
from constants import (
    DEFAULT_HEADERS,
    DEFAULT_SERVER_PROPERTIES,
    DEFAULT_SERVER_PROPERTIES_HEADER,
    HTTP_TIMEOUT,
)
from errors import DownloadError
import io


def downloadServerIcon(url: str, destination: Path) -> bool:
    print(f"Downloading server icon from {url}\t", end="", flush=True)
    response = requests.get(url, headers=DEFAULT_HEADERS,
                            timeout=HTTP_TIMEOUT, allow_redirects=True)
    if response.status_code != 200:
        raise DownloadError(
            f"Failed to download server icon from {url}: {response.status_code}")

    destination_file = destination / "server-icon.png"
    image = Image.open(io.BytesIO(response.content))

    if image.format != "png":
        image.save(destination_file, format="PNG", sizes=[(64, 64)])
    else:
        image.save(destination_file, sizes=[(64, 64)])

    print(f"OK")
    return True


def customizeServerProperties(destination: Path, config: Dict[str, str]) -> bool:
    print(
        f"Customizing server properties in {destination}", flush=True)
    server_properties_file = destination / "server.properties"

    if not server_properties_file.exists():
        print(f"Server properties file not found, creating default properties")
        defaultLines: list[str] = list(DEFAULT_SERVER_PROPERTIES_HEADER)
        for key, value in DEFAULT_SERVER_PROPERTIES.items():
            defaultLines.append(f"{key}={value}")
        server_properties_file.write_text("\n".join(defaultLines) + "\n")

    print(f"Merging server properties with custom config")

    existingLines: list[str] = server_properties_file.read_text().splitlines()
    updatedLines: list[str] = []
    appliedKeys: set[str] = set()

    for line in existingLines:
        strippedLine = line.strip()
        if not strippedLine or strippedLine.startswith("#") or "=" not in line:
            updatedLines.append(line)
            continue

        keyPart, _ = line.split("=", 1)
        normalizedKey = keyPart.strip()
        if normalizedKey in config:
            configValue = str(config[normalizedKey])
            updatedLines.append(f"{normalizedKey}={configValue}")
            appliedKeys.add(normalizedKey)
        else:
            updatedLines.append(line)

    for key, value in config.items():
        if key not in appliedKeys:
            valueText = str(value)
            updatedLines.append(f"{key}={valueText}")
            appliedKeys.add(key)

    server_properties_file.write_text("\n".join(updatedLines) + "\n")
    print(f"OK")
    return True

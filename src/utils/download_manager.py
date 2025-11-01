import requests
from constants import DEFAULT_HEADERS, HTTP_TIMEOUT, SERVER_JAR_URL
from pathlib import Path


def downloadServerJar(destination: Path, force: bool = False) -> bool:
    print(
        f"Downloading server jar from {SERVER_JAR_URL}\t", end="", flush=True)

    server_jar_file = destination / "server.jar"

    if server_jar_file.exists() and not force:
        print(f"SKIPPED")
        return True

    response = requests.get(SERVER_JAR_URL, headers=DEFAULT_HEADERS,
                            timeout=HTTP_TIMEOUT, allow_redirects=True)
    response.raise_for_status()

    server_jar_file.write_bytes(response.content)
    print(f"OK")
    return True

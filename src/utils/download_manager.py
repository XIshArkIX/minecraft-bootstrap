import requests
from constants import DEFAULT_HEADERS, HTTP_TIMEOUT, SERVER_JAR_URL
from pathlib import Path
from tqdm import tqdm

from utils.get_optimal_block_size import safe_get_optimal_block_size
from utils.int_context_manager import IntContextManager


def downloadServerJar(destination: Path, force: bool = False) -> bool:
    print(
        f"Downloading server jar from {SERVER_JAR_URL}", flush=True)

    server_jar_file = destination / "server.jar"

    if server_jar_file.exists() and not force:
        print(f"SKIPPED")
        return True

    response = requests.get(SERVER_JAR_URL, headers=DEFAULT_HEADERS,
                            timeout=HTTP_TIMEOUT, allow_redirects=True, stream=True)

    content_length = response.headers.get('content-length')

    if content_length is not None:
        with tqdm(total=int(content_length), unit='iB', unit_scale=True, desc=server_jar_file.name) as bar, IntContextManager(safe_get_optimal_block_size(destination)) as efficient_block_size, open(server_jar_file, 'wb') as file:
            for chunk in response.iter_content(chunk_size=efficient_block_size):
                if chunk:
                    file.write(chunk)
                    bar.update(len(chunk))
    else:
        server_jar_file.write_bytes(response.content)
        print("OK")
    return True

import io
import requests
from tqdm import tqdm
from constants import DEFAULT_HEADERS, HTTP_TIMEOUT
from errors import ExtractionError, InstallationError
import zipfile
from pathlib import Path

from utils.get_optimal_block_size import safe_get_optimal_block_size
from utils.int_context_manager import IntContextManager


def downloadServerPack(destination: Path, url: str) -> bytes:
    print(f"Downloading server pack from {url}", flush=True)
    response = requests.get(url, headers=DEFAULT_HEADERS,
                            timeout=HTTP_TIMEOUT, allow_redirects=True, stream=True)

    content_length = response.headers.get('content-length')

    destination_temporary_dir = destination / "tmp"
    destination_temporary_dir.mkdir(parents=True, exist_ok=True)

    destination_file = destination_temporary_dir / "pack.zip"

    if content_length is not None:
        with tqdm(total=int(content_length), unit='iB', unit_scale=True, desc="Progress") as bar, IntContextManager(safe_get_optimal_block_size(destination)) as efficient_block_size, open(destination_file, 'wb') as file:
            for chunk in response.iter_content(chunk_size=efficient_block_size):
                if chunk:
                    bar.update(len(chunk))
                    file.write(chunk)

    with open(destination_file, 'rb') as file:
        bytes = file.read()
        file.close()
        destination_file.unlink(missing_ok=True)
        destination_temporary_dir.rmdir()
        return bytes


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
    print(f"Bootstrapping manual server", flush=True)
    source = downloadServerPack(destination, url)
    try:
        extractServerPack(source, destination)
    except ExtractionError as exc:
        raise InstallationError(
            f"Failed to install server pack: {exc}") from exc
    print(f"Manual server bootstrapped successfully")
    return True

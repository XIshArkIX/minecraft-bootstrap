from __future__ import annotations

import sys

from constants import ServerType
from errors import ApplicationError, CurseForgeApiError
from utils.environment import (
    EnvironmentConfig,
    collectEnvironment,
    printStatus,
)
from utils.files import createEulaFile, downloadFile, extractZipArchive
from utils.curseforge_api import CurseForgeClient, extractDownloadUrl
from utils.http_client import fetchServerJarUrl, testHttpConnectivity




def handleVanillaServer(config: EnvironmentConfig) -> None:
    print("Preparing VANILLA server bootstrap...")

    eulaPath = createEulaFile(config.workingDir)
    printStatus("EULA file", True, str(eulaPath))

    print("Testing HTTP connectivity...")
    testHttpConnectivity()
    printStatus("HTTP connectivity", True)

    print("Fetching server.jar URL...")
    serverJarUrl = fetchServerJarUrl(config.version)
    printStatus("Server.jar URL", True, serverJarUrl)

    destination = config.workingDir / "server.jar"
    print(f"Downloading server.jar to {destination}...")
    downloadFile(serverJarUrl, destination)
    printStatus("server.jar", True, str(destination))


def handleCurseforgeServer(config: EnvironmentConfig) -> None:
    print("Preparing CURSEFORGE server bootstrap...")

    eulaPath = createEulaFile(config.workingDir)
    printStatus("EULA file", True, str(eulaPath))

    if config.curseforgeApiToken is None or config.curseforgeModpackId is None:
        raise CurseForgeApiError("CurseForge configuration is incomplete; missing API token or modpack ID")

    with CurseForgeClient(config.curseforgeApiToken) as curseforgeClient:
        print("Fetching modpack metadata from CurseForge...")
        modpackResponse = curseforgeClient.getLatestModpackFile(config.curseforgeModpackId)
        printStatus("CurseForge API", True, f"{len(modpackResponse.data)} file(s) returned")

        downloadUrl = extractDownloadUrl(modpackResponse)
        if downloadUrl is None:
            printStatus("Modpack download URL", False, "not present in API response")
            raise CurseForgeApiError("Modpack download URL not found in CurseForge API response")
        printStatus("Modpack download URL", True, downloadUrl)

        print("Downloading modpack archive...")
        modpackData = curseforgeClient.downloadModpackFile(downloadUrl)
        printStatus("Modpack download", True, f"{len(modpackData)} bytes")

    print("Extracting modpack archive...")
    extractZipArchive(modpackData, config.workingDir)
    printStatus("Modpack extraction", True, str(config.workingDir))

    print("CurseForge modpack server setup completed successfully.")


def main() -> None:
    try:
        config = collectEnvironment()
        if config.serverType == ServerType.VANILLA:
            handleVanillaServer(config)
        elif config.serverType == ServerType.CURSEFORGE:
            handleCurseforgeServer(config)
        else:
            raise NotImplementedError(f"Server type '{config.serverType.toString()}' is not implemented yet")
    except NotImplementedError as exc:
        print(f"Error: {exc}")
        sys.exit(2)
    except ApplicationError as exc:
        print(f"Error: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
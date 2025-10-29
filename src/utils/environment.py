from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from constants import ServerType
from errors import EnvironmentValidationError


@dataclass
class EnvironmentConfig:
    version: str
    workingDir: Path
    serverType: ServerType
    curseforgeApiToken: Optional[str] = None
    curseforgeModpackId: Optional[str] = None


def printStatus(label: str, success: bool, detail: Optional[str] = None) -> None:
    status = "OK" if success else "FAIL"
    message = f"{label}: {status}"
    if detail:
        message = f"{message} - {detail}"
    print(message)


def getEnv(name: str, optional: bool = False) -> Optional[str]:
    value = os.getenv(name)
    if value is None or value.strip() == "":
        if optional:
            return None
        raise EnvironmentValidationError(f"Environment variable '{name}' is required")
    return value.strip()


def validateSemver(version: str) -> bool:
    return bool(re.fullmatch(r"\d+\.\d+\.\d+", version))


def collectEnvironment() -> EnvironmentConfig:
    try:
        eulaValue = getEnv("EULA")
    except EnvironmentValidationError as exc:
        printStatus("EULA", False, str(exc))
        raise

    if eulaValue is not None and eulaValue.lower() != "true":
        printStatus("EULA", False, "must be 'true'")
        raise EnvironmentValidationError("EULA must be accepted (set to 'true')")
    printStatus("EULA", True)

    try:
        versionValue = getEnv("VERSION")
    except EnvironmentValidationError as exc:
        printStatus("VERSION", False, str(exc))
        raise

    if versionValue is not None and not validateSemver(versionValue):
        printStatus("VERSION", False, "invalid semver format (expected X.Y.Z)")
        raise EnvironmentValidationError("VERSION must follow semantic versioning (X.Y.Z)")
    printStatus("VERSION", True, versionValue)

    try:
        workingDirValue = getEnv("WORKING_DIR")
    except EnvironmentValidationError as exc:
        printStatus("WORKING_DIR", False, str(exc))
        raise

    workingDir = Path(workingDirValue) if workingDirValue is not None else None
    if workingDir is not None and not workingDir.is_absolute():
        printStatus("WORKING_DIR", False, "path must be absolute")
        raise EnvironmentValidationError("WORKING_DIR must be an absolute path")
    if workingDir is not None:
        workingDir.mkdir(parents=True, exist_ok=True)
    printStatus("WORKING_DIR", True, str(workingDir))

    try:
        serverTypeValue = getEnv("TYPE")
    except EnvironmentValidationError as exc:
        printStatus("TYPE", False, str(exc))
        raise

    serverType = ServerType.fromString(serverTypeValue) if serverTypeValue is not None else None
    if serverType is None:
        printStatus("TYPE", False, "must be VANILLA or CURSEFORGE")
        raise EnvironmentValidationError("Unsupported server type")
    printStatus("TYPE", True, serverType.toString())

    curseforgeApiToken: Optional[str] = None
    curseforgeModpackId: Optional[str] = None

    if serverType == ServerType.CURSEFORGE:
        curseforgeApiToken = getEnv("CURSEFORGE_API_TOKEN", optional=True)
        if curseforgeApiToken is None:
            curseforgeApiToken = getEnv("CF_API_TOKEN", optional=True)
        if curseforgeApiToken is None or curseforgeApiToken.strip() == "":
            printStatus("CURSEFORGE_API_TOKEN", False, "set CURSEFORGE_API_TOKEN or CF_API_TOKEN")
            raise EnvironmentValidationError("CURSEFORGE_API_TOKEN or CF_API_TOKEN must be provided for CurseForge server type")
        curseforgeApiToken = curseforgeApiToken.strip()
        printStatus("CURSEFORGE_API_TOKEN", True)

        curseforgeModpackId = getEnv("CURSEFORGE_MODPACK_ID", optional=True)
        if curseforgeModpackId is None:
            curseforgeModpackId = getEnv("CF_MODPACK_ID", optional=True)
        if curseforgeModpackId is None or curseforgeModpackId.strip() == "":
            printStatus("CURSEFORGE_MODPACK_ID", False, "set CURSEFORGE_MODPACK_ID or CF_MODPACK_ID")
            raise EnvironmentValidationError("CURSEFORGE_MODPACK_ID or CF_MODPACK_ID must be provided for CurseForge server type")
        curseforgeModpackId = curseforgeModpackId.strip()
        printStatus("CURSEFORGE_MODPACK_ID", True, curseforgeModpackId)

    return EnvironmentConfig(
        version=versionValue if versionValue is not None else "",
        workingDir=workingDir if workingDir is not None else Path("."),
        serverType=serverType,
        curseforgeApiToken=curseforgeApiToken,
        curseforgeModpackId=curseforgeModpackId,
    )




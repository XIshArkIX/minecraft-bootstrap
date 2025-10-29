from __future__ import annotations

import io
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional

import requests

from constants import DEFAULT_HEADERS, DOWNLOAD_BUFFER_SIZE, HTTP_TIMEOUT
from errors import CurseForgeApiError, ModpackDownloadError


CURSEFORGE_API_BASE_URL = "https://api.curseforge.com"


def _parseInt(value: Any) -> Optional[int]:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value)
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return None
        try:
            return int(stripped)
        except ValueError:
            return None
    return None


def _toInt(value: Any, default: int = 0) -> int:
    parsed = _parseInt(value)
    return parsed if parsed is not None else default


def _toOptionalInt(value: Any) -> Optional[int]:
    return _parseInt(value)


def _toOptionalBool(value: Any) -> Optional[bool]:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return bool(value)
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes"}:
            return True
        if lowered in {"false", "0", "no"}:
            return False
    return None


def _toStr(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value)


def _mapList(items: Iterable[Any], mapper):
    return [mapper(item) for item in items if isinstance(item, dict)]


@dataclass
class FileHash:
    value: str = ""
    algo: int = 0

    @classmethod
    def fromDict(cls, data: Dict[str, Any]) -> "FileHash":
        return cls(
            value=_toStr(data.get("value")),
            algo=_toInt(data.get("algo")),
        )


@dataclass
class SortableGameVersion:
    gameVersionName: str = ""
    gameVersionPadded: str = ""
    gameVersion: str = ""
    gameVersionReleaseDate: str = ""
    gameVersionTypeId: Optional[int] = None

    @classmethod
    def fromDict(cls, data: Dict[str, Any]) -> "SortableGameVersion":
        return cls(
            gameVersionName=_toStr(data.get("gameVersionName")),
            gameVersionPadded=_toStr(data.get("gameVersionPadded")),
            gameVersion=_toStr(data.get("gameVersion")),
            gameVersionReleaseDate=_toStr(data.get("gameVersionReleaseDate")),
            gameVersionTypeId=_toOptionalInt(data.get("gameVersionTypeId")),
        )


@dataclass
class FileDependency:
    modId: int = 0
    relationType: int = 0

    @classmethod
    def fromDict(cls, data: Dict[str, Any]) -> "FileDependency":
        return cls(
            modId=_toInt(data.get("modId")),
            relationType=_toInt(data.get("relationType")),
        )


@dataclass
class FileModule:
    name: str = ""
    fingerprint: int = 0

    @classmethod
    def fromDict(cls, data: Dict[str, Any]) -> "FileModule":
        return cls(
            name=_toStr(data.get("name")),
            fingerprint=_toInt(data.get("fingerprint")),
        )


@dataclass
class FileData:
    id: int = 0
    gameId: int = 0
    modId: int = 0
    isAvailable: bool = False
    displayName: str = ""
    fileName: str = ""
    releaseType: int = 0
    fileStatus: int = 0
    hashes: List[FileHash] = field(default_factory=list)
    fileDate: str = ""
    fileLength: int = 0
    downloadCount: int = 0
    fileSizeOnDisk: Optional[int] = None
    downloadUrl: Optional[str] = None
    gameVersions: List[str] = field(default_factory=list)
    sortableGameVersions: List[SortableGameVersion] = field(default_factory=list)
    dependencies: List[FileDependency] = field(default_factory=list)
    exposeAsAlternative: Optional[bool] = None
    parentProjectFileId: Optional[int] = None
    alternateFileId: Optional[int] = None
    isServerPack: Optional[bool] = None
    serverPackFileId: Optional[int] = None
    isEarlyAccessContent: Optional[bool] = None
    earlyAccessEndDate: Optional[str] = None
    fileFingerprint: int = 0
    modules: List[FileModule] = field(default_factory=list)

    @classmethod
    def fromDict(cls, data: Dict[str, Any]) -> "FileData":
        return cls(
            id=_toInt(data.get("id")),
            gameId=_toInt(data.get("gameId")),
            modId=_toInt(data.get("modId")),
            isAvailable=bool(data.get("isAvailable", False)),
            displayName=_toStr(data.get("displayName")),
            fileName=_toStr(data.get("fileName")),
            releaseType=_toInt(data.get("releaseType")),
            fileStatus=_toInt(data.get("fileStatus")),
            hashes=_mapList(data.get("hashes", []), FileHash.fromDict),
            fileDate=_toStr(data.get("fileDate")),
            fileLength=_toInt(data.get("fileLength")),
            downloadCount=_toInt(data.get("downloadCount")),
            fileSizeOnDisk=_toOptionalInt(data.get("fileSizeOnDisk")),
            downloadUrl=_toStr(data.get("downloadUrl")) if data.get("downloadUrl") is not None else None,
            gameVersions=[_toStr(item) for item in data.get("gameVersions", [])],
            sortableGameVersions=_mapList(data.get("sortableGameVersions", []), SortableGameVersion.fromDict),
            dependencies=_mapList(data.get("dependencies", []), FileDependency.fromDict),
            exposeAsAlternative=_toOptionalBool(data.get("exposeAsAlternative")),
            parentProjectFileId=_toOptionalInt(data.get("parentProjectFileId")),
            alternateFileId=_toOptionalInt(data.get("alternateFileId")),
            isServerPack=_toOptionalBool(data.get("isServerPack")),
            serverPackFileId=_toOptionalInt(data.get("serverPackFileId")),
            isEarlyAccessContent=_toOptionalBool(data.get("isEarlyAccessContent")),
            earlyAccessEndDate=_toStr(data.get("earlyAccessEndDate")) if data.get("earlyAccessEndDate") is not None else None,
            fileFingerprint=_toInt(data.get("fileFingerprint")),
            modules=_mapList(data.get("modules", []), FileModule.fromDict),
        )


@dataclass
class Pagination:
    index: int = 0
    pageSize: int = 0
    resultCount: int = 0
    totalCount: int = 0

    @classmethod
    def fromDict(cls, data: Dict[str, Any]) -> "Pagination":
        return cls(
            index=_toInt(data.get("index")),
            pageSize=_toInt(data.get("pageSize")),
            resultCount=_toInt(data.get("resultCount")),
            totalCount=_toInt(data.get("totalCount")),
        )


@dataclass
class GetFilesResponse:
    data: List[FileData] = field(default_factory=list)
    pagination: Optional[Pagination] = None


def parseGetFilesResponse(payload: Dict[str, Any]) -> GetFilesResponse:
    if not isinstance(payload, dict):
        raise CurseForgeApiError("CurseForge API response payload is not a JSON object")

    rawData = payload.get("data", [])
    if not isinstance(rawData, list):
        raise CurseForgeApiError("CurseForge API response payload is missing a 'data' array")

    files = [FileData.fromDict(item) for item in rawData if isinstance(item, dict)]

    paginationData = payload.get("pagination")
    pagination = Pagination.fromDict(paginationData) if isinstance(paginationData, dict) else None

    return GetFilesResponse(data=files, pagination=pagination)


def extractDownloadUrl(response: GetFilesResponse) -> Optional[str]:
    if not response.data:
        return None
    return response.data[0].downloadUrl


@dataclass
class CurseForgeClient:
    apiToken: str
    session: requests.Session = field(default_factory=requests.Session)

    def __post_init__(self) -> None:
        self.session.headers.update({
            "User-Agent": DEFAULT_HEADERS.get("User-Agent", "playtime-minecraft-bootstrap/py"),
        })

    def __enter__(self) -> "CurseForgeClient":
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self.close()

    def close(self) -> None:
        self.session.close()

    def getLatestModpackFile(self, modpackId: str) -> GetFilesResponse:
        url = (
            f"{CURSEFORGE_API_BASE_URL}/v1/mods/{modpackId}/files"
            "?pageIndex=0&pageSize=1&sort=dateCreated&sortDescending=true&removeAlphas=true"
        )

        headers = {
            "x-api-key": self.apiToken,
            "Accept": "application/json",
        }

        try:
            response = self.session.get(
                url,
                headers=headers,
                timeout=HTTP_TIMEOUT,
            )
        except requests.RequestException as exc:
            raise CurseForgeApiError(f"Failed to fetch modpack files from CurseForge API: {exc}") from exc

        if response.status_code >= 400:
            raise CurseForgeApiError(
                f"CurseForge API returned HTTP {response.status_code} for modpack '{modpackId}'"
            )

        try:
            payload = response.json()
        except ValueError as exc:
            raise CurseForgeApiError("CurseForge API response is not valid JSON") from exc

        return parseGetFilesResponse(payload)

    def downloadModpackFile(self, downloadUrl: str) -> bytes:
        headers = {
            "x-api-key": self.apiToken,
            "Accept": DEFAULT_HEADERS.get("Accept", "*/*"),
        }

        try:
            response = self.session.get(
                downloadUrl,
                headers=headers,
                timeout=HTTP_TIMEOUT,
                stream=True,
            )
        except requests.RequestException as exc:
            raise ModpackDownloadError(
                f"Failed to download modpack archive from '{downloadUrl}': {exc}"
            ) from exc

        if response.status_code >= 400:
            raise ModpackDownloadError(
                f"CurseForge download returned HTTP {response.status_code} for '{downloadUrl}'"
            )

        buffer = io.BytesIO()

        try:
            for chunk in response.iter_content(chunk_size=DOWNLOAD_BUFFER_SIZE):
                if chunk:
                    buffer.write(chunk)
        except requests.RequestException as exc:
            raise ModpackDownloadError(
                f"Error while streaming modpack archive from '{downloadUrl}': {exc}"
            ) from exc

        return buffer.getvalue()



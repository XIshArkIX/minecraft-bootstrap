from __future__ import annotations

from enum import Enum
from typing import Dict, Tuple


class ServerType(Enum):
    VANILLA = "VANILLA"
    CURSEFORGE = "CURSEFORGE"

    @classmethod
    def fromString(cls, value: str) -> "ServerType | None":
        try:
            return cls(value)
        except ValueError:
            return None

    def toString(self) -> str:
        return self.value


HTTP_TIMEOUT: Tuple[int, int] = (10, 120)
DOWNLOAD_BUFFER_SIZE: int = 1024 * 256
DEFAULT_HEADERS: Dict[str, str] = {
    "User-Agent": "playtime-minecraft-bootstrap/py",
    "Accept": "*/*",
}




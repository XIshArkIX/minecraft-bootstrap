from __future__ import annotations

from enum import Enum
from typing import Dict, Tuple


class ServerType(Enum):
    VANILLA = "VANILLA"
    CURSEFORGE = "CURSEFORGE"
    MANUAL = "MANUAL"

    @classmethod
    def fromString(cls, value: str) -> "ServerType | None":
        try:
            return cls(value)
        except ValueError:
            return None

    def toString(self) -> str:
        return self.value


SERVER_JAR_URL = "https://github.com/neoforged/ServerStarterJar/releases/latest/download/server.jar"

HTTP_TIMEOUT: Tuple[int, int] = (10, 120)
DEFAULT_HEADERS: Dict[str, str] = {
    "User-Agent": "playtime-minecraft-bootstrap/py",
    "Accept": "*/*",
}

DEFAULT_SERVER_PROPERTIES_HEADER: tuple[str, ...] = (
    "#Minecraft server properties",
    "#Wed Dec 23 23:04:12 CET 2020",
)

DEFAULT_SERVER_PROPERTIES: Dict[str, str] = {
    "allow-flight": "true",
    "allow-nether": "true",
    "broadcast-console-to-ops": "true",
    "broadcast-rcon-to-ops": "true",
    "difficulty": "hard",
    "enable-command-block": "true",
    "enable-jmx-monitoring": "false",
    "enable-query": "false",
    "enable-rcon": "false",
    "enable-status": "true",
    "enforce-whitelist": "true",
    "entity-broadcast-range-percentage": "100",
    "force-gamemode": "false",
    "function-permission-level": "2",
    "gamemode": "survival",
    "generate-structures": "true",
    "generator-settings": "",
    "hardcore": "false",
    "level-name": "Legendary Edition",
    "level-seed": "",
    "level-type": "bclib:normal",
    "max-build-height": "256",
    "max-players": "10",
    "max-tick-time": "120000",
    "max-world-size": "29999984",
    "motd": "Minecraft Legendary Edition",
    "network-compression-threshold": "256",
    "online-mode": "true",
    "op-permission-level": "4",
    "player-idle-timeout": "0",
    "prevent-proxy-connections": "false",
    "pvp": "true",
    "query.port": "25565",
    "rate-limit": "0",
    "rcon.password": "",
    "rcon.port": "25575",
    "resource-pack": "",
    "resource-pack-sha1": "",
    "server-ip": "",
    "server-port": "25565",
    "snooper-enabled": "false",
    "spawn-animals": "true",
    "spawn-monsters": "true",
    "spawn-npcs": "true",
    "spawn-protection": "16",
    "sync-chunk-writes": "true",
    "text-filtering-config": "",
    "use-native-transport": "true",
    "view-distance": "8",
}

import argparse
import sys
from pathlib import Path
from typing import Dict
from errors import ApplicationError
from utils.server_customization import downloadServerIcon, customizeServerProperties
from utils.vanilla_module import vanillaBootstrap
from utils.manual_module import manualBootstrap
from utils.download_manager import downloadServerJar
# from utils.curseforge_module import curseforgeBootstrap


parser = argparse.ArgumentParser(description="Playtime Minecraft Bootstrap")
parser.add_argument("--accept-eula",
                    help="Accept the EULA", type=bool, required=True)
parser.add_argument("--type", type=str, required=True, help="The type of server to bootstrap",
                    choices=["vanilla", "curseforge", "manual"])
parser.add_argument("--destination", type=str, required=True,
                    help="The destination of the server to bootstrap")
parser.add_argument("--version", type=str,
                    help="The Minecraft version to bootstrap")
parser.add_argument("--server-pack-url", type=str,
                    help="The URL of the server pack to bootstrap")
parser.add_argument("--server-icon-url", type=str,
                    help="The URL of the server icon to use")
parser.add_argument("--pass-if-exists", type=bool, required=False,
                    help="Pass if the modpack already exists in the destination directory", default=False)
parser.add_argument("--force-install", type=bool, required=False,
                    help="Force the installation of the server", default=False)
parser.add_argument("--download-server-jar", type=bool, required=False,
                    help="Download the server jar", default=False)
parser.add_argument("--server-property",
                    dest="server_properties",
                    action="append",
                    default=[],
                    metavar="key=value",
                    help="Override entries in server.properties (can be passed multiple times)")


def buildServerProperties(pairs: list[str]) -> Dict[str, str]:
    config: Dict[str, str] = {}
    for pair in pairs:
        if "=" not in pair:
            parser.error(f"Server property must look like key=value: {pair}")
        key, value = pair.split("=", 1)
        config[key.strip()] = value.strip()
    return config


if __name__ == "__main__":
    try:
        args = parser.parse_args()

        if not args.accept_eula:
            raise parser.error(
                "The EULA must be accepted to bootstrap a server")

        destination = Path(args.destination)
        destination.mkdir(parents=True, exist_ok=True)

        files = destination.glob("*")
        has_files = any([file.name != "eula.txt" for file in files])

        if has_files:
            if args.pass_if_exists:
                raise SystemExit(0)
            if not args.force_install:
                raise parser.error(
                    "The destination directory is not empty. Use --force-install to overwrite it")

        eula_file = destination / "eula.txt"
        if not eula_file.exists():
            eula_file.write_text(
                "#By changing the setting below to TRUE you are indicating your agreement to our EULA (https://aka.ms/MinecraftEULA).\neula=true")

        if args.type == "vanilla":
            if args.version is None:
                raise parser.error(
                    "The Minecraft version is required for vanilla bootstrap")

            vanillaBootstrap(args.version, destination)
        # elif args.type == "curseforge":
        #     curseforgeBootstrap(args.server_pack_url, args.destination)
        elif args.type == "manual":
            if args.server_pack_url is None:
                raise parser.error(
                    "The server pack URL is required for manual bootstrap")

            manualBootstrap(args.server_pack_url, destination)

            if args.download_server_jar:
                downloadServerJar(destination, args.force_install)

        serverProperties = buildServerProperties(args.server_properties)
        if serverProperties:
            customizeServerProperties(destination, serverProperties)

        if args.server_icon_url is not None:
            downloadServerIcon(args.server_icon_url,
                               destination)

    except ApplicationError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)

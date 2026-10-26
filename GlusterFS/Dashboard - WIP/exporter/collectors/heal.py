# Heal collector

import subprocess
import xml.etree.ElementTree as ET

from pydantic import BaseModel

from .common import host_command

class HealBrickStats(BaseModel):
    host: str
    path: str
    host_uuid: str
    status: str
    pending_entries: int

class HealVolumeStats(BaseModel):
    name: str
    bricks: list[HealBrickStats]
    total_pending: int
    connected: bool

class HealStats(BaseModel):
    volumes: list[HealVolumeStats]

class HealCollector:
    def _run(self, command: list[str]) -> str:
        result = subprocess.run(
            host_command(command, network=True),
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

        if result.returncode != 0:
            raise RuntimeError(
                f"Command failed: {' '.join(command)}\n"
                f"{result.stderr.strip()}"
            )

        return result.stdout

    @staticmethod
    def _parse_int(value: str | None) -> int:
        if value is None:
            return 0

        try:
            return int(value)
        except ValueError:
            return 0

    def _get_volumes(self) -> list[str]:
        xml = self._run(
            ["gluster", "volume", "list", "--xml"]
        )

        root = ET.fromstring(xml)

        return [
            volume.text
            for volume in root.findall(".//volList/volume")
            if volume.text
        ]

    def _parse_heal(
        self,
        volume_name: str,
        xml: str,
    ) -> HealVolumeStats:
        root = ET.fromstring(xml)

        bricks = []

        for brick in root.findall(
            ".//healInfo/bricks/brick"
        ):
            name = brick.findtext(
                "name",
                default="",
            )

            if ":" in name:
                host, path = name.split(":", 1)
            else:
                host = ""
                path = name

            status = brick.findtext(
                "status",
                default="Unknown",
            )

            pending_entries = self._parse_int(
                brick.findtext("numberOfEntries")
            )

            bricks.append(
                HealBrickStats(
                    host=host,
                    path=path,
                    host_uuid=brick.get(
                        "hostUuid",
                        "",
                    ),
                    status=status,
                    pending_entries=pending_entries,
                )
            )

        total_pending = sum(
            brick.pending_entries
            for brick in bricks
        )

        connected = (
            all(
                brick.status.lower() == "connected"
                for brick in bricks
            )
            if bricks
            else False
        )

        return HealVolumeStats(
            name=volume_name,
            bricks=bricks,
            total_pending=total_pending,
            connected=connected,
        )

    def collect(self) -> HealStats:
        volumes = []

        for volume_name in self._get_volumes():
            xml = self._run(
                [
                    "gluster",
                    "volume",
                    "heal",
                    volume_name,
                    "info",
                    "--xml",
                ]
            )

            volumes.append(
                self._parse_heal(
                    volume_name,
                    xml,
                )
            )

        return HealStats(volumes=volumes)
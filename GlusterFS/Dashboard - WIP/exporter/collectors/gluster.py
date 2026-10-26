# Gluster collector

import subprocess
import xml.etree.ElementTree as ET

from pydantic import BaseModel

from .common import host_command

class NodeStats(BaseModel):
    hostname: str
    uuid: str
    state: str
    connected: bool

class BrickStats(BaseModel):
    host: str
    path: str
    peer_id: str
    port: int | None
    pid: int | None
    online: bool

class VolumeStats(BaseModel):
    name: str
    volume_id: str
    volume_type: str
    status: str
    brick_count: int
    disperse_data: int | None
    disperse_redundancy: int | None
    transport: str
    bricks: list[BrickStats]

class GlusterStats(BaseModel):
    node_count: int
    nodes: list[NodeStats]
    volumes: list[VolumeStats]

class GlusterCollector:
    def _run(self, command: list[str]) -> str:
        result = subprocess.run(
            host_command(command, network=True),
            capture_output=True,
            text=True,
            check=False,
            timeout=15,
        )

        if result.returncode != 0:
            raise RuntimeError(
                f"Command failed: {' '.join(command)}\n"
                f"{result.stderr.strip()}"
            )

        return result.stdout

    @staticmethod
    def _parse_int(value: str | None) -> int | None:
        if value is None or value == "N/A":
            return None

        try:
            return int(value)
        except ValueError:
            return None

    def _parse_peers(self, xml: str) -> list[NodeStats]:
        root = ET.fromstring(xml)
        peers = []

        for peer in root.findall(".//peer"):
            peers.append(
                NodeStats(
                    hostname=peer.findtext(
                        "hostname",
                        default="",
                    ),
                    uuid=peer.findtext(
                        "uuid",
                        default="",
                    ),
                    state=peer.findtext(
                        "stateStr",
                        default="Local node",
                    ),
                    connected=peer.findtext(
                        "connected",
                        default="0",
                    ) == "1",
                )
            )

        return peers

    def _parse_volumes(
        self,
        info_xml: str,
        status_xml: str,
    ) -> list[VolumeStats]:
        info_root = ET.fromstring(info_xml)
        status_root = ET.fromstring(status_xml)

        runtime_bricks: dict[
            tuple[str, str],
            BrickStats,
        ] = {}

        for node in status_root.findall(
            ".//volStatus/volumes/volume/node"
        ):
            hostname = node.findtext(
                "hostname",
                default="",
            )
            path = node.findtext(
                "path",
                default="",
            )

            if hostname == "Self-heal Daemon":
                continue

            runtime_bricks[(hostname, path)] = BrickStats(
                host=hostname,
                path=path,
                peer_id=node.findtext(
                    "peerid",
                    default="",
                ),
                port=self._parse_int(
                    node.findtext("port")
                ),
                pid=self._parse_int(
                    node.findtext("pid")
                ),
                online=node.findtext(
                    "status",
                    default="0",
                ) == "1",
            )

        volumes = []

        for volume in info_root.findall(
            ".//volInfo/volumes/volume"
        ):
            bricks = []

            for brick in volume.findall(
                "bricks/brick"
            ):
                name = brick.findtext(
                    "name",
                    default="",
                )

                if ":" not in name:
                    continue

                host, path = name.split(":", 1)

                runtime = runtime_bricks.get(
                    (host, path)
                )

                if runtime:
                    bricks.append(runtime)
                else:
                    bricks.append(
                        BrickStats(
                            host=host,
                            path=path,
                            peer_id=brick.findtext(
                                "hostUuid",
                                default="",
                            ),
                            port=None,
                            pid=None,
                            online=False,
                        )
                    )

            disperse_count = self._parse_int(
                volume.findtext("disperseCount")
            )
            redundancy = self._parse_int(
                volume.findtext("redundancyCount")
            )

            disperse_data = None

            if (
                disperse_count is not None
                and redundancy is not None
            ):
                disperse_data = (
                    disperse_count - redundancy
                )

            transport_code = volume.findtext(
                "transport",
                default="",
            )

            transport = {
                "0": "tcp",
                "1": "rdma",
                "2": "tcp,rdma",
            }.get(
                transport_code,
                transport_code or "Unknown",
            )

            volumes.append(
                VolumeStats(
                    name=volume.findtext(
                        "name",
                        default="",
                    ),
                    volume_id=volume.findtext(
                        "id",
                        default="",
                    ),
                    volume_type=volume.findtext(
                        "typeStr",
                        default="Unknown",
                    ),
                    status=volume.findtext(
                        "statusStr",
                        default="Unknown",
                    ),
                    brick_count=self._parse_int(
                        volume.findtext("brickCount")
                    ) or 0,
                    disperse_data=disperse_data,
                    disperse_redundancy=redundancy,
                    transport=transport,
                    bricks=bricks,
                )
            )

        return volumes

    def collect(self) -> GlusterStats:
        pool_xml = self._run(
            ["gluster", "pool", "list", "--xml"]
        )

        info_xml = self._run(
            ["gluster", "volume", "info", "--xml"]
        )

        status_xml = self._run(
            ["gluster", "volume", "status", "--xml"]
        )

        peers = self._parse_peers(pool_xml)

        volumes = self._parse_volumes(
            info_xml,
            status_xml,
        )

        for node in peers:
            if node.hostname != "localhost":
                continue

            local_host = next(
                (
                    brick.host
                    for volume in volumes
                    for brick in volume.bricks
                    if brick.peer_id == node.uuid
                ),
                None,
            )

            if local_host:
                node.hostname = local_host

            node.state = "Local node"

        return GlusterStats(
            node_count=len(peers),
            nodes=peers,
            volumes=volumes,
        )
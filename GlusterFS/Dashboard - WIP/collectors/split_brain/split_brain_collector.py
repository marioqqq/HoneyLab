import subprocess
import time
import xml.etree.ElementTree as ET

from pydantic import BaseModel


class SplitBrainVolumeStats(BaseModel):
    name: str
    volume_type: str
    supported: bool
    split_brain: bool
    affected_files: list[str]
    file_count: int


class SplitBrainStats(BaseModel):
    volumes: list[SplitBrainVolumeStats]


class SplitBrainCollector:
    def _run(self, command: list[str]) -> tuple[int, str, str]:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

        return (
            result.returncode,
            result.stdout,
            result.stderr,
        )

    def _get_volumes(self) -> list[tuple[str, str]]:
        return_code, stdout, stderr = self._run(
            ["gluster", "volume", "info", "--xml"]
        )

        if return_code != 0:
            raise RuntimeError(
                f"Command failed: gluster volume info --xml\n"
                f"{stderr.strip()}"
            )

        root = ET.fromstring(stdout)

        volumes = []

        for volume in root.findall(
            ".//volInfo/volumes/volume"
        ):
            name = volume.findtext(
                "name",
                default="",
            )

            volume_type = volume.findtext(
                "typeStr",
                default="Unknown",
            )

            if name:
                volumes.append(
                    (name, volume_type)
                )

        return volumes

    def _parse_split_brain(
        self,
        xml: str,
    ) -> tuple[list[str], bool]:
        root = ET.fromstring(xml)

        affected_files = []

        for element in root.iter():
            if element.tag in {
                "path",
                "file",
            } and element.text:
                affected_files.append(
                    element.text
                )

        return (
            affected_files,
            bool(affected_files),
        )

    def collect(self) -> SplitBrainStats:
        volumes = []

        for volume_name, volume_type in self._get_volumes():
            supported = volume_type.lower() == "replicate"

            if not supported:
                volumes.append(
                    SplitBrainVolumeStats(
                        name=volume_name,
                        volume_type=volume_type,
                        supported=False,
                        split_brain=False,
                        affected_files=[],
                        file_count=0,
                    )
                )

                continue

            return_code, stdout, stderr = self._run(
                [
                    "gluster",
                    "volume",
                    "heal",
                    volume_name,
                    "info",
                    "split-brain",
                    "--xml",
                ]
            )

            if return_code != 0:
                raise RuntimeError(
                    f"Split-brain query failed for "
                    f"{volume_name}:\n"
                    f"{stderr.strip()}"
                )

            affected_files, split_brain = (
                self._parse_split_brain(stdout)
            )

            volumes.append(
                SplitBrainVolumeStats(
                    name=volume_name,
                    volume_type=volume_type,
                    supported=True,
                    split_brain=split_brain,
                    affected_files=affected_files,
                    file_count=len(
                        affected_files
                    ),
                )
            )

        return SplitBrainStats(
            volumes=volumes
        )


if __name__ == "__main__":
    collector = SplitBrainCollector()

    while True:
        try:
            print(
                collector.collect().model_dump_json(
                    indent=2
                )
            )
        except Exception as error:
            print(
                f"Collector error: {error}"
            )

        print("-" * 80)
        time.sleep(5)
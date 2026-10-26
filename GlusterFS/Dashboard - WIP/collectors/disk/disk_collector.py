import subprocess
import time

import psutil
from pydantic import BaseModel


class DiskIOStats(BaseModel):
    read_bytes: int
    write_bytes: int
    read_operations: int
    write_operations: int
    read_time_ms: int
    write_time_ms: int
    read_mb_s: float
    write_mb_s: float
    read_iops: float
    write_iops: float
    read_latency_ms: float
    write_latency_ms: float


class FilesystemStats(BaseModel):
    device: str
    mountpoint: str
    filesystem: str
    total: int
    used: int
    free: int
    usage: float


class DiskStats(BaseModel):
    devices: dict[str, DiskIOStats]
    filesystems: list[FilesystemStats]


class DiskCollector:
    def __init__(self):
        self._previous: dict[
            str,
            tuple[int, int, int, int, int, int, float],
        ] = {}

    def _get_disks(self) -> set[str]:
        try:
            result = subprocess.run(
                ["lsblk", "-dn", "-o", "NAME,TYPE"],
                capture_output=True,
                text=True,
                check=False,
                timeout=5,
            )
        except (subprocess.SubprocessError, OSError):
            return set()

        disks = set()

        for line in result.stdout.splitlines():
            parts = line.split()

            if len(parts) != 2:
                continue

            name, device_type = parts

            if device_type == "disk":
                disks.add(name)

        return disks

    def collect(self) -> DiskStats:
        io_counters = psutil.disk_io_counters(
            perdisk=True
        )

        disks = self._get_disks()
        now = time.monotonic()

        devices = {}

        for name, counter in io_counters.items():
            if name not in disks:
                continue

            read_mb_s = 0.0
            write_mb_s = 0.0
            read_iops = 0.0
            write_iops = 0.0
            read_latency_ms = 0.0
            write_latency_ms = 0.0

            if name in self._previous:
                (
                    previous_read_bytes,
                    previous_write_bytes,
                    previous_read_ops,
                    previous_write_ops,
                    previous_read_time,
                    previous_write_time,
                    previous_time,
                ) = self._previous[name]

                elapsed = now - previous_time

                if elapsed > 0:
                    read_bytes_delta = (
                        counter.read_bytes
                        - previous_read_bytes
                    )

                    write_bytes_delta = (
                        counter.write_bytes
                        - previous_write_bytes
                    )

                    read_ops_delta = (
                        counter.read_count
                        - previous_read_ops
                    )

                    write_ops_delta = (
                        counter.write_count
                        - previous_write_ops
                    )

                    read_time_delta = (
                        counter.read_time
                        - previous_read_time
                    )

                    write_time_delta = (
                        counter.write_time
                        - previous_write_time
                    )

                    read_mb_s = (
                        max(0, read_bytes_delta)
                        / elapsed
                        / 1_000_000
                    )

                    write_mb_s = (
                        max(0, write_bytes_delta)
                        / elapsed
                        / 1_000_000
                    )

                    read_iops = (
                        max(0, read_ops_delta)
                        / elapsed
                    )

                    write_iops = (
                        max(0, write_ops_delta)
                        / elapsed
                    )

                    if read_ops_delta > 0:
                        read_latency_ms = max(
                            0.0,
                            read_time_delta
                            / read_ops_delta,
                        )

                    if write_ops_delta > 0:
                        write_latency_ms = max(
                            0.0,
                            write_time_delta
                            / write_ops_delta,
                        )

            self._previous[name] = (
                counter.read_bytes,
                counter.write_bytes,
                counter.read_count,
                counter.write_count,
                counter.read_time,
                counter.write_time,
                now,
            )

            devices[name] = DiskIOStats(
                read_bytes=counter.read_bytes,
                write_bytes=counter.write_bytes,
                read_operations=counter.read_count,
                write_operations=counter.write_count,
                read_time_ms=counter.read_time,
                write_time_ms=counter.write_time,
                read_mb_s=read_mb_s,
                write_mb_s=write_mb_s,
                read_iops=read_iops,
                write_iops=write_iops,
                read_latency_ms=read_latency_ms,
                write_latency_ms=write_latency_ms,
            )

        filesystems = []

        for partition in psutil.disk_partitions(
            all=False
        ):
            try:
                usage = psutil.disk_usage(
                    partition.mountpoint
                )
            except (PermissionError, OSError):
                continue

            filesystems.append(
                FilesystemStats(
                    device=partition.device,
                    mountpoint=partition.mountpoint,
                    filesystem=partition.fstype,
                    total=usage.total,
                    used=usage.used,
                    free=usage.free,
                    usage=usage.percent,
                )
            )

        return DiskStats(
            devices=devices,
            filesystems=filesystems,
        )


if __name__ == "__main__":
    collector = DiskCollector()

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
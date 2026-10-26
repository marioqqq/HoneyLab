import json
import subprocess

from pydantic import BaseModel


class SmartDisk(BaseModel):
    device: str
    model: str | None
    serial: str | None
    firmware: str | None
    smart_available: bool
    smart_enabled: bool
    health: str
    temperature_c: float | None
    power_on_hours: int | None
    reallocated_sectors: int | None
    pending_sectors: int | None
    uncorrectable_errors: int | None


class SmartStats(BaseModel):
    disks: list[SmartDisk]


class SmartCollector:
    def __init__(self):
        self.devices = self._get_devices()

    def _get_devices(self) -> list[str]:
        result = subprocess.run(
            ["lsblk", "-dn", "-o", "NAME,TYPE"],
            capture_output=True,
            text=True,
            check=False,
            timeout=5,
        )

        return [
            f"/dev/{parts[0]}"
            for line in result.stdout.splitlines()
            if len(parts := line.split()) == 2 and parts[1] == "disk"
        ]

    @staticmethod
    def _unknown(device: str) -> SmartDisk:
        return SmartDisk(
            device=device,
            model=None,
            serial=None,
            firmware=None,
            smart_available=False,
            smart_enabled=False,
            health="unknown",
            temperature_c=None,
            power_on_hours=None,
            reallocated_sectors=None,
            pending_sectors=None,
            uncorrectable_errors=None,
        )

    def _read_smart(self, device: str) -> SmartDisk:
        try:
            result = subprocess.run(
                ["smartctl", "-j", "-a", device],
                capture_output=True,
                text=True,
                check=False,
                timeout=10,
            )
            data = json.loads(result.stdout)
        except (subprocess.SubprocessError, OSError, json.JSONDecodeError):
            return self._unknown(device)

        support = data.get("smart_support", {})
        smart_available = bool(support.get("available", False))
        smart_enabled = bool(support.get("enabled", False))

        status = data.get("smart_status", {}).get("passed")
        health = "passed" if status is True else "failed" if status is False else "unknown"

        temperature = data.get("temperature", {}).get("current")
        power_on_hours = data.get("power_on_time", {}).get("hours")

        attributes = {
            item.get("name"): item.get("raw", {}).get("value")
            for item in data.get("ata_smart_attributes", {}).get("table", [])
            if item.get("name")
        }

        # NVMe exposes several values in a separate SMART log.
        nvme = data.get("nvme_smart_health_information_log", {})
        if temperature is None:
            temperature = nvme.get("temperature")
        if power_on_hours is None:
            power_on_hours = nvme.get("power_on_hours")

        uncorrectable = attributes.get("Offline_Uncorrectable")
        if uncorrectable is None:
            uncorrectable = nvme.get("media_errors")

        # Some devices/bridges omit smart_support but still return real SMART data.
        if not smart_available and (
            "smart_status" in data
            or "ata_smart_attributes" in data
            or "nvme_smart_health_information_log" in data
        ):
            smart_available = True

        return SmartDisk(
            device=device,
            model=data.get("model_name") or data.get("model_family"),
            serial=data.get("serial_number"),
            firmware=data.get("firmware_version"),
            smart_available=smart_available,
            smart_enabled=smart_enabled or smart_available,
            health=health,
            temperature_c=temperature,
            power_on_hours=power_on_hours,
            reallocated_sectors=attributes.get("Reallocated_Sector_Ct"),
            pending_sectors=attributes.get("Current_Pending_Sector"),
            uncorrectable_errors=uncorrectable,
        )

    def collect(self) -> SmartStats:
        return SmartStats(
            disks=[self._read_smart(device) for device in self.devices]
        )


if __name__ == "__main__":
    import time

    collector = SmartCollector()

    while True:
        print(collector.collect().model_dump_json(indent=2))
        print("-" * 80)
        time.sleep(5)

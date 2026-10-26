import subprocess
import time

from pydantic import BaseModel


class ServiceStatus(BaseModel):
    online: bool


class ServiceStats(BaseModel):
    smb: ServiceStatus
    nfs: ServiceStatus


class ServiceCollector:
    @staticmethod
    def _active(service: str) -> bool:
        try:
            result = subprocess.run(
                ["systemctl", "is-active", "--quiet", service],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
                check=False,
            )

            return result.returncode == 0

        except (subprocess.SubprocessError, OSError):
            return False

    def collect(self) -> ServiceStats:
        return ServiceStats(
            smb=ServiceStatus(
                online=self._active("smbd"),
            ),
            nfs=ServiceStatus(
                online=(
                    self._active("nfs-server")
                    or self._active("nfs-kernel-server")
                ),
            ),
        )


if __name__ == "__main__":
    collector = ServiceCollector()

    while True:
        print(
            collector.collect().model_dump_json(
                indent=2
            )
        )
        print("-" * 80)
        time.sleep(5)
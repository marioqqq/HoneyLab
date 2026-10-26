# Service collector

import subprocess

from pydantic import BaseModel

from .common import host_command

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
                host_command(["systemctl", "is-active", "--quiet", service]),
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
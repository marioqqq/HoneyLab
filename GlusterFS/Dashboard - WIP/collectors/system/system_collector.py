import platform
import time

import psutil
from pydantic import BaseModel


class LoadAverage(BaseModel):
    one: float
    five: float
    fifteen: float


class CPUStats(BaseModel):
    usage: float
    cores: int
    threads: int
    load: LoadAverage


class MemoryStats(BaseModel):
    total: int
    used: int
    available: int
    usage: float


class SwapStats(BaseModel):
    total: int
    used: int
    free: int
    usage: float


class SystemStats(BaseModel):
    hostname: str
    os: str
    kernel: str
    architecture: str
    uptime: int
    cpu: CPUStats
    memory: MemoryStats
    swap: SwapStats


class SystemCollector:
    def __init__(self):
        # First call establishes the CPU measurement baseline.
        psutil.cpu_percent(interval=None)

    def collect(self) -> SystemStats:
        memory = psutil.virtual_memory()
        swap = psutil.swap_memory()
        load = psutil.getloadavg()

        return SystemStats(
            hostname=platform.node(),
            os=platform.system(),
            kernel=platform.release(),
            architecture=platform.machine(),
            uptime=int(time.time() - psutil.boot_time()),
            cpu=CPUStats(
                usage=psutil.cpu_percent(interval=None),
                cores=psutil.cpu_count(logical=False) or 1,
                threads=psutil.cpu_count(logical=True) or 1,
                load=LoadAverage(
                    one=load[0],
                    five=load[1],
                    fifteen=load[2],
                ),
            ),
            memory=MemoryStats(
                total=memory.total,
                used=memory.used,
                available=memory.available,
                usage=memory.percent,
            ),
            swap=SwapStats(
                total=swap.total,
                used=swap.used,
                free=swap.free,
                usage=swap.percent,
            ),
        )


if __name__ == "__main__":
    collector = SystemCollector()

    while True:
        print(collector.collect().model_dump_json(indent=2))
        print("-" * 80)
        time.sleep(5)
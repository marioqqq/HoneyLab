import time

import psutil
from pydantic import BaseModel


class TrafficStats(BaseModel):
    bytes: int
    packets: int
    errors: int
    drops: int


class NetworkInterface(BaseModel):
    name: str
    state: str
    speed_mbps: float | None
    mtu: int
    rx: TrafficStats
    tx: TrafficStats
    rx_mbps: float
    tx_mbps: float


class NetworkStats(BaseModel):
    interfaces: list[NetworkInterface]


class NetworkCollector:
    def __init__(self):
        self._previous: dict[
            str,
            tuple[int, int, float],
        ] = {}

    def collect(self) -> NetworkStats:
        counters = psutil.net_io_counters(
            pernic=True
        )

        statuses = psutil.net_if_stats()

        now = time.monotonic()
        result = []

        for name, stats in statuses.items():
            if name not in counters:
                continue

            counter = counters[name]

            rx_mbps = 0.0
            tx_mbps = 0.0

            if name in self._previous:
                (
                    previous_rx,
                    previous_tx,
                    previous_time,
                ) = self._previous[name]

                elapsed = now - previous_time

                if elapsed > 0:
                    rx_mbps = (
                        (
                            counter.bytes_recv
                            - previous_rx
                        )
                        * 8
                        / elapsed
                        / 1_000_000
                    )

                    tx_mbps = (
                        (
                            counter.bytes_sent
                            - previous_tx
                        )
                        * 8
                        / elapsed
                        / 1_000_000
                    )

                    rx_mbps = max(
                        0.0,
                        rx_mbps,
                    )

                    tx_mbps = max(
                        0.0,
                        tx_mbps,
                    )

            self._previous[name] = (
                counter.bytes_recv,
                counter.bytes_sent,
                now,
            )

            speed_mbps = (
                float(stats.speed)
                if stats.speed > 0
                else None
            )

            result.append(
                NetworkInterface(
                    name=name,
                    state=(
                        "up"
                        if stats.isup
                        else "down"
                    ),
                    speed_mbps=speed_mbps,
                    mtu=stats.mtu,
                    rx=TrafficStats(
                        bytes=counter.bytes_recv,
                        packets=counter.packets_recv,
                        errors=counter.errin,
                        drops=counter.dropin,
                    ),
                    tx=TrafficStats(
                        bytes=counter.bytes_sent,
                        packets=counter.packets_sent,
                        errors=counter.errout,
                        drops=counter.dropout,
                    ),
                    rx_mbps=rx_mbps,
                    tx_mbps=tx_mbps,
                )
            )

        return NetworkStats(
            interfaces=result
        )


if __name__ == "__main__":
    collector = NetworkCollector()

    while True:
        print(
            collector.collect().model_dump_json(
                indent=2
            )
        )
        print("-" * 80)
        time.sleep(5)
# GlusterBoard Prometheus exporter

import os
import time

from prometheus_client import Gauge, start_http_server

from collectors.disk import DiskCollector
from collectors.gluster import GlusterCollector
from collectors.heal import HealCollector
from collectors.network import NetworkCollector
from collectors.service import ServiceCollector
from collectors.smart import SmartCollector
from collectors.split_brain import SplitBrainCollector
from collectors.system import SystemCollector

PORT = int(os.getenv("PORT", "9105"))
INTERVAL = float(os.getenv("INTERVAL", "5"))

COLLECTOR_TYPES = {
    "system": SystemCollector,
    "disk": DiskCollector,
    "network": NetworkCollector,
    "smart": SmartCollector,
    "gluster": GlusterCollector,
    "heal": HealCollector,
    "split_brain": SplitBrainCollector,
    "service": ServiceCollector,
}

# name: (help, labels)
METRICS = {
    # System
    "system_cpu_percent": ("CPU usage", ()),
    "system_ram_total_bytes": ("Total RAM", ()),
    "system_ram_used_bytes": ("Used RAM", ()),
    "system_ram_available_bytes": ("Available RAM", ()),
    "system_ram_usage_percent": ("RAM usage", ()),
    "system_swap_total_bytes": ("Total swap", ()),
    "system_swap_used_bytes": ("Used swap", ()),
    "system_swap_usage_percent": ("Swap usage", ()),
    "system_load": ("Load average", ("period",)),
    "system_uptime_seconds": ("System uptime", ()),

    # Disk / filesystem
    **{
        f"disk_{name}": (name, ("device",))
        for name in (
            "read_bytes_total", "write_bytes_total",
            "read_operations_total", "write_operations_total",
            "read_time_seconds_total", "write_time_seconds_total",
            "read_mb_per_second", "write_mb_per_second",
            "read_iops", "write_iops",
            "read_latency_ms", "write_latency_ms",
        )
    },
    "filesystem_total": ("Filesystem total", ("device", "mountpoint", "filesystem")),
    "filesystem_used": ("Filesystem used", ("device", "mountpoint", "filesystem")),
    "filesystem_free": ("Filesystem free", ("device", "mountpoint", "filesystem")),
    "filesystem_usage_percent": ("Filesystem usage_percent", ("device", "mountpoint", "filesystem")),

    # Network
    **{
        f"network_{name}": (name, ("interface",))
        for name in (
            "interface_up", "interface_speed_mbps",
            "receive_bytes_total", "transmit_bytes_total",
            "receive_packets_total", "transmit_packets_total",
            "receive_errors_total", "transmit_errors_total",
            "receive_drops_total", "transmit_drops_total",
            "receive_mbps", "transmit_mbps",
        )
    },

    # Services
    "smb_online": ("SMB service online", ()),
    "nfs_online": ("NFS service online", ()),

    # Gluster
    "gluster_nodes": ("Number of Gluster nodes", ()),
    "gluster_node_connected": ("Gluster node connection state", ("hostname", "uuid")),
    "gluster_volume_status": ("Gluster volume status", ("volume",)),
    "gluster_volume_bricks": ("Number of volume bricks", ("volume",)),
    "gluster_brick_online": ("Gluster brick state", ("volume", "host", "path")),
    "gluster_brick_port": ("Gluster brick port", ("volume", "host", "path")),
    "gluster_brick_pid": ("Gluster brick PID", ("volume", "host", "path")),

    # Heal / split brain
    "gluster_heal_pending_entries": ("Pending heal entries", ("volume", "host", "path")),
    "gluster_heal_connected": ("Heal brick connection state", ("volume", "host", "path")),
    "gluster_heal_total_pending_entries": ("Total pending heal entries", ("volume",)),
    "gluster_split_brain_supported": ("Split-brain query supported", ("volume",)),
    "gluster_split_brain_detected": ("Split-brain detected", ("volume",)),
    "gluster_split_brain_files": ("Split-brain affected files", ("volume",)),

    # SMART
    "smart_available": ("SMART available", ("device",)),
    "smart_enabled": ("SMART enabled", ("device",)),
    "smart_health": ("SMART health: 1 passed, 0 failed", ("device",)),
    "smart_temperature_celsius": ("SMART temperature", ("device",)),
    "smart_power_on_hours": ("SMART power-on hours", ("device",)),
    "smart_reallocated_sectors": ("SMART reallocated sectors", ("device",)),
    "smart_pending_sectors": ("SMART pending sectors", ("device",)),
    "smart_uncorrectable_errors": ("SMART uncorrectable errors", ("device",)),
}


def enabled(name: str) -> bool:
    return os.getenv(f"ENABLE_{name.upper()}", "true").strip().lower() not in {"0", "false", "no", "off"}


class GlusterBoardExporter:
    def __init__(self):
        self.collectors = {
            name: collector()
            for name, collector in COLLECTOR_TYPES.items()
            if enabled(name)
        }
        self.up = Gauge("glusterboard_collector_up", "Collector status", ["collector"])
        self.duration = Gauge("glusterboard_collector_duration_seconds", "Collector duration", ["collector"])
        self.m = {
            name: Gauge(f"glusterboard_{name}", help_text, labels)
            for name, (help_text, labels) in METRICS.items()
        }

    @staticmethod
    def _bool(value):
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return bool(value)
        return str(value).strip().lower() in {
            "1", "true", "yes", "up", "online", "connected",
            "ok", "healthy", "passed", "running", "started",
        }

    def _set(self, name, value, labels=()):
        if value is None:
            return
        metric = self.m[name]
        (metric.labels(*labels) if labels else metric).set(float(value))

    def _remove(self, name, labels):
        try:
            self.m[name].remove(*labels)
        except KeyError:
            pass

    def collect(self):
        for name, collector in self.collectors.items():
            start = time.monotonic()
            try:
                data = collector.collect()
                getattr(self, f"_export_{name}")(data)
                self.up.labels(name).set(1)
            except Exception as exc:
                self.up.labels(name).set(0)
                print(f"[ERROR] {name}: {exc}", flush=True)
            finally:
                self.duration.labels(name).set(time.monotonic() - start)

    def _export_system(self, d):
        values = {
            "system_cpu_percent": d.cpu.usage,
            "system_ram_total_bytes": d.memory.total,
            "system_ram_used_bytes": d.memory.used,
            "system_ram_available_bytes": d.memory.available,
            "system_ram_usage_percent": d.memory.usage,
            "system_swap_total_bytes": d.swap.total,
            "system_swap_used_bytes": d.swap.used,
            "system_swap_usage_percent": d.swap.usage,
            "system_uptime_seconds": d.uptime,
        }
        for name, value in values.items():
            self._set(name, value)
        for period, value in (("1m", d.cpu.load.one), ("5m", d.cpu.load.five), ("15m", d.cpu.load.fifteen)):
            self._set("system_load", value, (period,))

    def _export_disk(self, d):
        for device, s in d.devices.items():
            values = {
                "disk_read_bytes_total": s.read_bytes,
                "disk_write_bytes_total": s.write_bytes,
                "disk_read_operations_total": s.read_operations,
                "disk_write_operations_total": s.write_operations,
                "disk_read_time_seconds_total": s.read_time_ms / 1000,
                "disk_write_time_seconds_total": s.write_time_ms / 1000,
                "disk_read_mb_per_second": s.read_mb_s,
                "disk_write_mb_per_second": s.write_mb_s,
                "disk_read_iops": s.read_iops,
                "disk_write_iops": s.write_iops,
                "disk_read_latency_ms": s.read_latency_ms,
                "disk_write_latency_ms": s.write_latency_ms,
            }
            for name, value in values.items():
                self._set(name, value, (device,))

        for fs in d.filesystems:
            labels = (fs.device, fs.mountpoint, fs.filesystem)
            for name, value in (
                ("filesystem_total", fs.total), ("filesystem_used", fs.used),
                ("filesystem_free", fs.free), ("filesystem_usage_percent", fs.usage),
            ):
                self._set(name, value, labels)

    def _export_network(self, d):
        for i in d.interfaces:
            labels = (i.name,)
            self._set("network_interface_up", self._bool(i.state), labels)
            if i.speed_mbps is None:
                self._remove("network_interface_speed_mbps", labels)
            else:
                self._set("network_interface_speed_mbps", i.speed_mbps, labels)

            for prefix, traffic in (("receive", i.rx), ("transmit", i.tx)):
                for suffix, value in (
                    ("bytes_total", traffic.bytes), ("packets_total", traffic.packets),
                    ("errors_total", traffic.errors), ("drops_total", traffic.drops),
                ):
                    self._set(f"network_{prefix}_{suffix}", value, labels)
            self._set("network_receive_mbps", i.rx_mbps, labels)
            self._set("network_transmit_mbps", i.tx_mbps, labels)

    def _export_service(self, d):
        self._set("smb_online", d.smb.online)
        self._set("nfs_online", d.nfs.online)

    def _export_gluster(self, d):
        self._set("gluster_nodes", d.node_count)
        for node in d.nodes:
            self._set("gluster_node_connected", node.connected, (node.hostname, node.uuid))
        for volume in d.volumes:
            labels = (volume.name,)
            self._set("gluster_volume_status", volume.status.lower() in {"started", "running", "online"}, labels)
            self._set("gluster_volume_bricks", volume.brick_count, labels)
            for brick in volume.bricks:
                labels = (volume.name, brick.host, brick.path)
                self._set("gluster_brick_online", brick.online, labels)
                self._set("gluster_brick_port", brick.port, labels)
                self._set("gluster_brick_pid", brick.pid, labels)

    def _export_heal(self, d):
        for volume in d.volumes:
            self._set("gluster_heal_total_pending_entries", volume.total_pending, (volume.name,))
            for brick in volume.bricks:
                labels = (volume.name, brick.host, brick.path)
                self._set("gluster_heal_pending_entries", brick.pending_entries, labels)
                self._set("gluster_heal_connected", brick.status.lower() == "connected", labels)

    def _export_split_brain(self, d):
        for volume in d.volumes:
            labels = (volume.name,)
            self._set("gluster_split_brain_supported", volume.supported, labels)
            self._set("gluster_split_brain_detected", volume.split_brain, labels)
            self._set("gluster_split_brain_files", volume.file_count, labels)

    def _export_smart(self, d):
        optional = (
            "smart_health", "smart_temperature_celsius", "smart_power_on_hours",
            "smart_reallocated_sectors", "smart_pending_sectors", "smart_uncorrectable_errors",
        )
        for disk in d.disks:
            labels = (disk.device,)
            self._set("smart_available", disk.smart_available, labels)
            self._set("smart_enabled", disk.smart_enabled, labels)
            if not disk.smart_available:
                for metric in optional:
                    self._remove(metric, labels)
                continue

            if disk.health in {"passed", "failed"}:
                self._set("smart_health", disk.health == "passed", labels)
            else:
                self._remove("smart_health", labels)

            values = {
                "smart_temperature_celsius": disk.temperature_c,
                "smart_power_on_hours": disk.power_on_hours,
                "smart_reallocated_sectors": disk.reallocated_sectors,
                "smart_pending_sectors": disk.pending_sectors,
                "smart_uncorrectable_errors": disk.uncorrectable_errors,
            }
            for name, value in values.items():
                self._remove(name, labels) if value is None else self._set(name, value, labels)


if __name__ == "__main__":
    start_http_server(PORT)
    exporter = GlusterBoardExporter()
    enabled_names = ", ".join(exporter.collectors)
    print(f"GlusterBoard exporter listening on 0.0.0.0:{PORT}/metrics")
    print(f"Collectors: {enabled_names}")

    while True:
        exporter.collect()
        time.sleep(INTERVAL)

import time

from prometheus_client import Gauge, start_http_server

from gluster.gluster_collector import GlusterCollector
from heal.heal_collector import HealCollector
from split_brain.split_brain_collector import SplitBrainCollector
from system.system_collector import SystemCollector
from disk.disk_collector import DiskCollector
from smart.smart_collector import SmartCollector
from network.network_collector import NetworkCollector
from service.service_collector import ServiceCollector

PORT = 9105
INTERVAL = 5


class GlusterBoardExporter:
    def __init__(self):
        self.collectors = {
            "gluster": GlusterCollector(),
            "heal": HealCollector(),
            "split_brain": SplitBrainCollector(),
            "system": SystemCollector(),
            "disk": DiskCollector(),
            "smart": SmartCollector(),
            "network": NetworkCollector(),
            "service": ServiceCollector(),
        }

        self.up = Gauge(
            "glusterboard_collector_up",
            "Collector status",
            ["collector"],
        )

        self.duration = Gauge(
            "glusterboard_collector_duration_seconds",
            "Collector duration",
            ["collector"],
        )

        self.m = {}

        def add(name, help_text, labels=()):
            self.m[name] = Gauge(
                f"glusterboard_{name}",
                help_text,
                labels,
            )

        # System
        add("system_cpu_percent", "CPU usage")
        add("system_ram_total_bytes", "Total RAM")
        add("system_ram_used_bytes", "Used RAM")
        add("system_ram_available_bytes", "Available RAM")
        add("system_ram_usage_percent", "RAM usage")
        add("system_swap_total_bytes", "Total swap")
        add("system_swap_used_bytes", "Used swap")
        add("system_swap_usage_percent", "Swap usage")
        add("system_load", "Load average", ("period",))
        add("system_uptime_seconds", "System uptime")

        # Disk
        for name in (
            "read_bytes_total",
            "write_bytes_total",
            "read_operations_total",
            "write_operations_total",
            "read_time_seconds_total",
            "write_time_seconds_total",
            "read_mb_per_second",
            "write_mb_per_second",
            "read_iops",
            "write_iops",
            "read_latency_ms",
            "write_latency_ms",
        ):
            add(f"disk_{name}", name, ("device",))

        for name in ("total", "used", "free", "usage_percent"):
            metric = (
                f"filesystem_{name}"
                if name != "usage_percent"
                else "filesystem_usage_percent"
            )
            add(metric, f"Filesystem {name}", ("device", "mountpoint", "filesystem"))

        # Network
        for name in (
            "interface_up",
            "interface_speed_mbps",
            "receive_bytes_total",
            "transmit_bytes_total",
            "receive_packets_total",
            "transmit_packets_total",
            "receive_errors_total",
            "transmit_errors_total",
            "receive_drops_total",
            "transmit_drops_total",
            "receive_mbps",
            "transmit_mbps",
        ):
            add(f"network_{name}", name, ("interface",))

        # Services
        add("smb_online", "SMB service online")
        add("nfs_online", "NFS service online")

        # Gluster
        add("gluster_nodes", "Number of Gluster nodes")
        add("gluster_node_connected", "Gluster node connection state", ("hostname", "uuid"))
        add("gluster_volume_status", "Gluster volume status", ("volume",))
        add("gluster_volume_bricks", "Number of volume bricks", ("volume",))
        add("gluster_brick_online", "Gluster brick state", ("volume", "host", "path"))
        add("gluster_brick_port", "Gluster brick port", ("volume", "host", "path"))
        add("gluster_brick_pid", "Gluster brick PID", ("volume", "host", "path"))

        # Heal
        add("gluster_heal_pending_entries", "Pending heal entries", ("volume", "host", "path"))
        add("gluster_heal_connected", "Heal brick connection state", ("volume", "host", "path"))
        add("gluster_heal_total_pending_entries", "Total pending heal entries", ("volume",))

        # Split brain
        add("gluster_split_brain_supported", "Split-brain query supported", ("volume",))
        add("gluster_split_brain_detected", "Split-brain detected", ("volume",))
        add("gluster_split_brain_files", "Split-brain affected files", ("volume",))

        # SMART
        add("smart_available", "SMART available", ("device",))
        add("smart_enabled", "SMART enabled", ("device",))
        add("smart_health", "SMART health: 1 passed, 0 failed", ("device",))
        add("smart_temperature_celsius", "SMART temperature", ("device",))
        add("smart_power_on_hours", "SMART power-on hours", ("device",))
        add("smart_reallocated_sectors", "SMART reallocated sectors", ("device",))
        add("smart_pending_sectors", "SMART pending sectors", ("device",))
        add("smart_uncorrectable_errors", "SMART uncorrectable errors", ("device",))

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
        child = metric.labels(*labels) if labels else metric
        child.set(float(value))

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
                print(f"[ERROR] {name}: {exc}")
            finally:
                self.duration.labels(name).set(time.monotonic() - start)

    def _export_system(self, d):
        self._set("system_cpu_percent", d.cpu.usage)
        self._set("system_ram_total_bytes", d.memory.total)
        self._set("system_ram_used_bytes", d.memory.used)
        self._set("system_ram_available_bytes", d.memory.available)
        self._set("system_ram_usage_percent", d.memory.usage)
        self._set("system_swap_total_bytes", d.swap.total)
        self._set("system_swap_used_bytes", d.swap.used)
        self._set("system_swap_usage_percent", d.swap.usage)
        self._set("system_load", d.cpu.load.one, ("1m",))
        self._set("system_load", d.cpu.load.five, ("5m",))
        self._set("system_load", d.cpu.load.fifteen, ("15m",))
        self._set("system_uptime_seconds", d.uptime)

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
            for metric, value in values.items():
                self._set(metric, value, (device,))

        for fs in d.filesystems:
            labels = (fs.device, fs.mountpoint, fs.filesystem)
            self._set("filesystem_total", fs.total, labels)
            self._set("filesystem_used", fs.used, labels)
            self._set("filesystem_free", fs.free, labels)
            self._set("filesystem_usage_percent", fs.usage, labels)

    def _export_network(self, d):
        for i in d.interfaces:
            labels = (i.name,)
            self._set("network_interface_up", self._bool(i.state), labels)

            if i.speed_mbps is None:
                self._remove("network_interface_speed_mbps", labels)
            else:
                self._set("network_interface_speed_mbps", i.speed_mbps, labels)

            for prefix, traffic in (("receive", i.rx), ("transmit", i.tx)):
                self._set(f"network_{prefix}_bytes_total", traffic.bytes, labels)
                self._set(f"network_{prefix}_packets_total", traffic.packets, labels)
                self._set(f"network_{prefix}_errors_total", traffic.errors, labels)
                self._set(f"network_{prefix}_drops_total", traffic.drops, labels)

            self._set("network_receive_mbps", i.rx_mbps, labels)
            self._set("network_transmit_mbps", i.tx_mbps, labels)

    def _export_service(self, d):
        self._set("smb_online", d.smb.online)
        self._set("nfs_online", d.nfs.online)

    def _export_gluster(self, d):
        self._set("gluster_nodes", d.node_count)

        for node in d.nodes:
            self._set(
                "gluster_node_connected",
                node.connected,
                (node.hostname, node.uuid),
            )

        for volume in d.volumes:
            self._set(
                "gluster_volume_status",
                volume.status.lower() in {"started", "running", "online"},
                (volume.name,),
            )
            self._set("gluster_volume_bricks", volume.brick_count, (volume.name,))

            for brick in volume.bricks:
                labels = (volume.name, brick.host, brick.path)
                self._set("gluster_brick_online", brick.online, labels)
                self._set("gluster_brick_port", brick.port, labels)
                self._set("gluster_brick_pid", brick.pid, labels)

    def _export_heal(self, d):
        for volume in d.volumes:
            self._set(
                "gluster_heal_total_pending_entries",
                volume.total_pending,
                (volume.name,),
            )

            for brick in volume.bricks:
                labels = (volume.name, brick.host, brick.path)
                self._set("gluster_heal_pending_entries", brick.pending_entries, labels)
                self._set(
                    "gluster_heal_connected",
                    brick.status.lower() == "connected",
                    labels,
                )

    def _export_split_brain(self, d):
        for volume in d.volumes:
            labels = (volume.name,)
            self._set("gluster_split_brain_supported", volume.supported, labels)
            self._set("gluster_split_brain_detected", volume.split_brain, labels)
            self._set("gluster_split_brain_files", volume.file_count, labels)

    def _export_smart(self, d):
        optional = (
            "smart_health",
            "smart_temperature_celsius",
            "smart_power_on_hours",
            "smart_reallocated_sectors",
            "smart_pending_sectors",
            "smart_uncorrectable_errors",
        )

        for disk in d.disks:
            labels = (disk.device,)
            self._set("smart_available", disk.smart_available, labels)
            self._set("smart_enabled", disk.smart_enabled, labels)

            if not disk.smart_available:
                for metric in optional:
                    self._remove(metric, labels)
                continue

            if disk.health == "passed":
                self._set("smart_health", 1, labels)
            elif disk.health == "failed":
                self._set("smart_health", 0, labels)
            else:
                self._remove("smart_health", labels)

            values = {
                "smart_temperature_celsius": disk.temperature_c,
                "smart_power_on_hours": disk.power_on_hours,
                "smart_reallocated_sectors": disk.reallocated_sectors,
                "smart_pending_sectors": disk.pending_sectors,
                "smart_uncorrectable_errors": disk.uncorrectable_errors,
            }

            for metric, value in values.items():
                if value is None:
                    self._remove(metric, labels)
                else:
                    self._set(metric, value, labels)


if __name__ == "__main__":
    start_http_server(PORT)
    print(f"GlusterBoard exporter listening on 0.0.0.0:{PORT}/metrics")

    exporter = GlusterBoardExporter()

    while True:
        exporter.collect()
        time.sleep(INTERVAL)
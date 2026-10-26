const collator = new Intl.Collator(undefined, {
        numeric: true,
        sensitivity: "base",
    });

function nodeName(item) {
    return item.node ?? item.instance ?? "Unknown";
}

function compare(a, b) {
    return collator.compare(String(a ?? ""), String(b ?? ""));
}

function percent(value) {
    return `${Number(value ?? 0).toFixed(1)}%`;
}

function bytes(value) {
    const units = ["B", "KB", "MB", "GB", "TB",];
    let number = Number(value ?? 0);
    let unit = 0;
    while (number >= 1000 && unit < units.length - 1) {
        number /= 1000;
        unit++;
    }
    return `${number.toFixed(1)} ${units[unit]}`;
}

function uptime(value) {
    let seconds = Number(value ?? 0);
    const days = Math.floor(seconds / 86400);
    seconds %= 86400;
    const hours = Math.floor(seconds / 3600);
    if (days > 0) {
        return `${days}d ${hours}h`;
    }
    return `${hours}h`;
}

function state(value, good = "Online", bad = "Offline") {
    return Number(value) === 1
        ? `<span class="ok">${good}</span>`
        : `<span class="error">${bad}</span>`;
}

function findValue(series, predicate) {
    const item = series.find(predicate);
    return item?.value;
}

function sortNodeDevice(values, field) {
    return values.sort((a, b) => compare(a.node, b.node) || compare(a[field], b[field]));
}

/* NODE CARDS */

function buildNodes(data) {
    const container = document.getElementById("nodes-grid");
    container.innerHTML = "";
    const nodes = {};

    function get(name) {
        nodes[name] ??= {
            cpu: 0,
            ram: 0,
            swap: 0,
            uptime: 0,
            load1: 0,
            load5: 0,
            load15: 0,
            smb: undefined,
            nfs: undefined,
        };
        return nodes[name];
    }
    for (const item of data.cpu) {
        get(nodeName(item)).cpu = item.value;
    }
    for (const item of data.ram) {
        get(nodeName(item)).ram = item.value;
    }
    for (const item of data.swap) {
        get(nodeName(item)).swap = item.value;
    }
    for (const item of data.uptime) {
        get(nodeName(item)).uptime = item.value;
    }
    for (const item of data.load) {
        const node = get(nodeName(item));
        if (item.period === "1m") {
            node.load1 = item.value;
        }
        if (item.period === "5m") {
            node.load5 = item.value;
        }
        if (item.period === "15m") {
            node.load15 = item.value;
        }
    }
    for (const item of data.smb_online) {
        get(nodeName(item)).smb = item.value;
    }
    for (const item of data.nfs_online) {
        get(nodeName(item)).nfs = item.value;
    }
    for (const name of Object.keys(nodes).sort(compare)) {
        const n = nodes[name];
        const card = document.createElement("div");
        card.className = "node-card";
        card.innerHTML = `
            <div class="node-title">
                <h3>${name}</h3>
                <span>${uptime(n.uptime)}</span>
            </div>
            ${progress("CPU", n.cpu)}
            ${progress("RAM", n.ram)}
            ${progress("Swap", n.swap)}
            <div class="load-row">
                <span>
                    Load 1m
                    <strong>${n.load1.toFixed(2)}</strong>
                </span>
                <span>
                    Load 5m
                    <strong>${n.load5.toFixed(2)}</strong>
                </span>
                <span>
                    Load 15m
                    <strong>${n.load15.toFixed(2)}</strong>
                </span>
            </div>
            ${serviceBlock("SMB", n.smb)}
            ${serviceBlock("NFS", n.nfs)}
        `;
        container.appendChild(card);
    }
}

function progress(name, value) {
    value = Number(value ?? 0);
    return `
        <div class="metric">
            <div class="metric-header">
                <span>${name}</span>
                <span>${percent(value)}</span>
            </div>
            <div class="progress">
                <div
                    style="width:${Math.min(value, 100)}%"
                ></div>
            </div>
        </div>
    `;
}

function serviceBlock(name, online) {
    let status;
    if (online === undefined || online === null) {
        status = '<span class="muted">Not available</span>';
    }
    else {
        status = state(online, "Online", "Offline");
    }
    return `
        <div class="service-block">
            <div class="service-row compact">
                <strong>${name}</strong>
                ${status}
            </div>
        </div>
    `;
}

/* VOLUMES */

function buildVolumes(data) {
    const table = document.getElementById("volume-table");
    table.innerHTML = "";
    const volumes = {};

    function get(name) {
        volumes[name] ??= {
            name,
            status: 0,
            bricks: 0,
            pending: 0,
            split: 0,
            supported: 0,
        };
        return volumes[name];
    }
    for (const item of data.volumes) {
        get(item.volume).status = item.value;
    }
    for (const item of data.volume_bricks) {
        get(item.volume).bricks = item.value;
    }
    for (const item of data.heal_total) {
        get(item.volume).pending = item.value;
    }
    for (const item of data.split_files) {
        get(item.volume).split = item.value;
    }
    for (const item of data.split_supported) {
        get(item.volume).supported = item.value;
    }
    for (const volume of Object.values(volumes).sort((a, b) => compare(a.name, b.name))) {
        const split = Number(volume.supported) === 0 ? '<span class="muted">N/A</span>' : Number(volume.split) > 0
                    ? `<span class="error">
                        ${volume.split} files
                       </span>`
                    : '<span class="ok">None</span>';
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${volume.name}</td>
            <td>
                ${state(volume.status, "Started", "Stopped")}
            </td>
            <td>${volume.bricks}</td>
            <td class="${
                volume.pending > 0 ? "error" : ""
            }">
                ${volume.pending}
            </td>
            <td>${split}</td>
        `;
        table.appendChild(row);
    }
}

/* BRICKS + HEAL */

function buildBricks(data) {
    const table = document.getElementById("brick-table");
    table.innerHTML = "";
    const bricks = {};

    function key(item) {
        return [item.volume, item.host, item.path,].join("|");
    }
    for (const item of data.bricks_online) {
        bricks[key(item)] = {
            volume: item.volume,
            host: item.host,
            path: item.path,
            online: item.value,
        };
    }
    for (const item of data.heal_connected) {
        const k = key(item);
        bricks[k] ??= {
            volume: item.volume,
            host: item.host,
            path: item.path,
        };
        bricks[k].heal = item.value;
    }
    for (const item of data.heal_pending) {
        const k = key(item);
        bricks[k] ??= {
            volume: item.volume,
            host: item.host,
            path: item.path,
        };
        bricks[k].pending = item.value;
    }
    for (const item of data.brick_ports) {
        const k = key(item);
        if (bricks[k]) {
            bricks[k].port = item.value;
        }
    }
    for (const item of data.brick_pids) {
        const k = key(item);
        if (bricks[k]) {
            bricks[k].pid = item.value;
        }
    }
    const values = Object.values(bricks).sort((a, b) => compare(a.volume, b.volume) || compare(a.host, b.host)
                || compare(a.path, b.path));
    for (const brick of values) {
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${brick.volume}</td>
            <td>${brick.host}</td>
            <td>${brick.path}</td>
            <td>
                ${state(brick.online)}
            </td>
            <td>
                ${state(brick.heal, "Connected", "Disconnected")}
            </td>
            <td class="${
                Number(brick.pending) > 0 ? "error" : ""
            }">
                ${Number(brick.pending ?? 0)}
            </td>
            <td>${brick.port ?? "-"}</td>
            <td>${brick.pid ?? "-"}</td>
        `;
        table.appendChild(row);
    }
}

/* FILESYSTEMS */

function buildFilesystems(data) {
    const table = document.getElementById("filesystem-table");
    table.innerHTML = "";
    const filesystems = {};

    function add(series, field) {
        for (const item of series) {
            const node = nodeName(item);
            const key = [node, item.device, item.mountpoint,].join("|");
            filesystems[key] ??= {
                node,
                device: item.device,
                mountpoint: item.mountpoint,
            };
            filesystems[key][field] = item.value;
        }
    }
    add(data.filesystem_usage, "usage");
    add(data.filesystem_total, "total");
    add(data.filesystem_used, "used");
    add(data.filesystem_free, "free");
    const values = sortNodeDevice(Object.values(filesystems), "device");
    for (const fs of values) {
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${fs.node}</td>
            <td>${fs.device}</td>
            <td>${fs.mountpoint}</td>
            <td>${bytes(fs.used)}</td>
            <td>${bytes(fs.free)}</td>
            <td>${bytes(fs.total)}</td>
            <td>${percent(fs.usage)}</td>
        `;
        table.appendChild(row);
    }
}

/* DISKS */

function buildDisks(data) {
    const table = document.getElementById("disk-table");
    table.innerHTML = "";
    const disks = {};

    function add(series, field) {
        for (const item of series) {
            const node = nodeName(item);
            const key =
                `${node}|${item.device}`;
            disks[key] ??= {
                node,
                device: item.device,
            };
            disks[key][field] = item.value;
        }
    }
    add(data.disk_read, "read");
    add(data.disk_write, "write");
    add(data.disk_read_iops, "readIops");
    add(data.disk_write_iops, "writeIops");
    add(data.disk_read_latency, "readLatency");
    add(data.disk_write_latency, "writeLatency");
    const values = sortNodeDevice(Object.values(disks), "device");
    for (const disk of values) {
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${disk.node}</td>
            <td>${disk.device}</td>
            <td>
                ${(disk.read ?? 0).toFixed(2)} MB/s
            </td>
            <td>
                ${(disk.write ?? 0).toFixed(2)} MB/s
            </td>
            <td>
                ${(disk.readIops ?? 0).toFixed(1)}
            </td>
            <td>
                ${(disk.writeIops ?? 0).toFixed(1)}
            </td>
            <td>
                ${(disk.readLatency ?? 0).toFixed(2)} ms
            </td>
            <td>
                ${(disk.writeLatency ?? 0).toFixed(2)} ms
            </td>
        `;
        table.appendChild(row);
    }
}

/* NETWORK */

function buildNetwork(data) {
    const table = document.getElementById("network-table");
    table.innerHTML = "";
    const interfaces = {};

    function add(series, field) {
        for (const item of series) {
            if (!item.interface ?.startsWith("ens")) {
                continue;
            }
            const node = nodeName(item);
            const key =
                `${node}|${item.interface}`;
            interfaces[key] ??= {
                node,
                interface: item.interface,
            };
            interfaces[key][field] = item.value;
        }
    }
    add(data.network_up, "up");
    add(data.network_speed, "speed");
    add(data.network_rx, "rx");
    add(data.network_tx, "tx");
    add(data.network_rx_packets, "rxPackets");
    add(data.network_tx_packets, "txPackets");
    add(data.network_rx_errors, "rxErrors");
    add(data.network_tx_errors, "txErrors");
    add(data.network_rx_drops, "rxDrops");
    add(data.network_tx_drops, "txDrops");
    const values = sortNodeDevice(Object.values(interfaces), "interface");
    for (const iface of values) {
        const errors = Number(iface.rxErrors ?? 0) + Number(iface.txErrors ?? 0);
        const drops = Number(iface.rxDrops ?? 0) + Number(iface.txDrops ?? 0);
        const speed = Number(iface.speed ?? 0);
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${iface.node}</td>
            <td>${iface.interface}</td>
            <td>
                ${state(iface.up, "Up", "Down")}
            </td>
            <td>
                ${
                    speed > 0
                        ? `${speed} Mbps`
                        : "-"
                }
            </td>
            <td>
                ${(iface.rx ?? 0).toFixed(2)} Mbps
            </td>
            <td>
                ${(iface.tx ?? 0).toFixed(2)} Mbps
            </td>
            <td>
                ${Number(iface.rxPackets ?? 0).toLocaleString()}
            </td>
            <td>
                ${Number(iface.txPackets ?? 0).toLocaleString()}
            </td>
            <td class="${
                errors > 0 ? "warning" : ""
            }">
                ${errors}
            </td>
            <td class="${
                drops > 0 ? "warning" : ""
            }">
                ${drops}
            </td>
        `;
        table.appendChild(row);
    }
}

/* SMART */

function buildSmart(data) {
    const table = document.getElementById("smart-table");
    table.innerHTML = "";
    const disks = {};

    function add(series, field) {
        for (const item of series) {
            const node = nodeName(item);
            const key =
                `${node}|${item.device}`;
            disks[key] ??= {
                node,
                device: item.device,
            };
            disks[key][field] = item.value;
        }
    }
    add(data.smart_available, "available");
    add(data.smart_enabled, "enabled");
    add(data.smart_health, "health");
    add(data.smart_temperature, "temperature");
    add(data.smart_power_on_hours, "hours");
    add(data.smart_reallocated, "reallocated");
    add(data.smart_pending, "pending");
    add(data.smart_errors, "errors");
    const values = sortNodeDevice(Object.values(disks), "device");
    for (const disk of values) {
        let smartState;
        if (Number(disk.available) !== 1) {
            smartState = '<span class="muted">Unavailable</span>';
        }
        else if (Number(disk.enabled) === 1) {
            smartState = '<span class="ok">Enabled</span>';
        }
        else {
            smartState = '<span class="warning">Disabled</span>';
        }
        let health = "-";
        if (Number(disk.available) === 1) {
            if (Number(disk.health) === 1) {
                health = '<span class="ok">Passed</span>';
            }
            else if (disk.health !== undefined) {
                health = '<span class="error">Failed</span>';
            }
            else {
                health = "Unknown";
            }
        }
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${disk.node}</td>
            <td>${disk.device}</td>
            <td>${smartState}</td>
            <td>${health}</td>
            <td>
                ${
                    disk.temperature !== undefined
                        ? `${disk.temperature.toFixed(0)} °C`
                        : "-"
                }
            </td>
            <td>
                ${
                    disk.hours !== undefined
                        ? `${disk.hours.toFixed(0)} h`
                        : "-"
                }
            </td>
            <td>
                ${disk.reallocated ?? "-"}
            </td>
            <td>
                ${disk.pending ?? "-"}
            </td>
            <td>
                ${disk.errors ?? "-"}
            </td>
        `;
        table.appendChild(row);
    }
}

/* COLLECTORS */

function buildCollectors(data) {
    const table = document.getElementById("collector-table");
    table.innerHTML = "";
    const collectors = {};
    for (const item of data.collectors) {
        const node = nodeName(item);
        const key =
            `${node}|${item.collector}`;
        collectors[key] = {
            node,
            collector: item.collector,
            status: item.value,
        };
    }
    for (const item of data.collector_duration) {
        const node = nodeName(item);
        const key =
            `${node}|${item.collector}`;
        if (collectors[key]) {
            collectors[key].duration = item.value;
        }
    }
    const values = Object.values(collectors).sort((a, b) => compare(a.node, b.node) || compare(a.collector,
                    b.collector));
    for (const collector of values) {
        const row = document.createElement("tr");
        row.innerHTML = `
            <td>${collector.node}</td>
            <td>${collector.collector}</td>
            <td>
                ${state(collector.status, "OK", "Failed")}
            </td>
            <td>
                ${(Number(collector.duration ?? 0) * 1000).toFixed(1)} ms
            </td>
        `;
        table.appendChild(row);
    }
}

/* UPDATE */

async function update() {
    const refresh = document.getElementById("refresh");
    try {
        const response = await fetch("/api/overview");
        if (!response.ok) {
            throw new Error(
                `HTTP ${response.status}`
            );
        }
        const data = await response.json();
        const cluster = document.getElementById("cluster-status");
        cluster.textContent = data.healthy ? "Healthy" : "Degraded";
        cluster.className = data.healthy ? "ok" : "error";
        document.getElementById("nodes").textContent =
            `${data.nodes.online}/${data.nodes.total}`;
        document.getElementById("bricks").textContent =
            `${data.bricks.online}/${data.bricks.total}`;
        document.getElementById("heals").textContent = data.pending_heals;
        document.getElementById("split-brain").textContent = data.split_brain;
        buildNodes(data);
        buildVolumes(data);
        buildBricks(data);
        buildFilesystems(data);
        buildDisks(data);
        buildNetwork(data);
        buildSmart(data);
        buildCollectors(data);
        refresh.textContent =
            `Updated ${
                new Date() .toLocaleTimeString()
            }`;
    }
    catch (error) {
        refresh.textContent =
            `Update failed: ${error.message}`;
    }
}
update();
setInterval(update, 5000);
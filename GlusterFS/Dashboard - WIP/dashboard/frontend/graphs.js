let graphData = null;
let selectedRange = "5m";
const charts = {};
const collator = new Intl.Collator(undefined, {
        numeric: true,
        sensitivity: "base",
    });

/* TOOLTIP POSITIONER */
Chart.Tooltip.positioners.oppositeSide = function (elements, eventPosition) {
    if (!elements.length) {
        return false;
    }
    const chart = this.chart;
    const area = chart.chartArea;
    const middle = area.left + (area.right - area.left) / 2;
    /*
     * Cursor on left:
     * tooltip appears towards the right.
     *
     * Cursor on right:
     * tooltip appears towards the left.
     */
    if (eventPosition.x < middle) {
        return {
            x: Math.min(eventPosition.x + 30, area.right - 20),
            y: eventPosition.y,
            xAlign: "left",
            yAlign: "center",
        };
    }
    return {
        x: Math.max(eventPosition.x - 30, area.left + 20),
        y: eventPosition.y,
        xAlign: "right",
        yAlign: "center",
    };
};

/* VERTICAL HOVER LINE */
const verticalHoverLine = {
    id: "verticalHoverLine",
    afterDatasetsDraw(chart) {
        const tooltip = chart.tooltip;
        if (!tooltip || tooltip.opacity === 0) {
            return;
        }
        const x = tooltip.caretX;
        if (x < chart.chartArea.left || x > chart.chartArea.right) {
            return;
        }
        const ctx = chart.ctx;
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(x, chart.chartArea.top);
        ctx.lineTo(x, chart.chartArea.bottom);
        ctx.lineWidth = 1;
        ctx.strokeStyle = "rgba(180, 185, 195, 0.45)";
        ctx.setLineDash([4, 4]);
        ctx.stroke();
        ctx.restore();
    },
};
Chart.register(verticalHoverLine);

/* HELPERS */

function nodeName(series) {
    return (series.node ?? series.instance ?? "Unknown");
}

function sortedUnique(values) {
    return [...new Set(values.filter(Boolean))].sort((a, b) => collator.compare(a, b));
}

function makeDataset(series, label) {
    const values = [];
    const step = Number(graphData.step) * 1000;
    let previousTimestamp = null;
    for (const [timestamp, value] of series.values) {
        const currentTimestamp = timestamp * 1000;
        if (previousTimestamp !== null && currentTimestamp - previousTimestamp > step * 1.5) {
            values.push({
                x: previousTimestamp + step,
                y: null,
            });
        }
        values.push({
            x: currentTimestamp,
            y: value,
        });
        previousTimestamp = currentTimestamp;
    }
    return {
        label,
        data: values,
        borderWidth: 2,
        pointRadius: 0,
        pointHoverRadius: 3,
        pointStyle: "line",
        tension: 0.15,
        spanGaps: false,
    };
}

/* TIME FORMATTING */

function formatAxisTime(timestamp) {
    const date = new Date(timestamp);
    if (selectedRange === "5m" || selectedRange === "15m" || selectedRange === "30m") {
        return date.toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit",
            });
    }
    if (selectedRange === "1h" || selectedRange === "3h" || selectedRange === "6h" || selectedRange === "12h") {
        return date.toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
            });
    }
    if (selectedRange === "1d" || selectedRange === "1w") {
        return date.toLocaleString([], {
                month: "short",
                day: "numeric",
                hour: "2-digit",
                minute: "2-digit",
            });
    }
    return date.toLocaleDateString([], {
            year: "numeric",
            month: "short",
            day: "numeric",
        });
}

function formatTooltipTime(timestamp) {
    const date = new Date(timestamp);
    if (selectedRange === "5m" || selectedRange === "15m" || selectedRange === "30m" || selectedRange === "1h"
        || selectedRange === "3h" || selectedRange === "6h" || selectedRange === "12h") {
        return date.toLocaleString([], {
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit",
            });
    }
    if (selectedRange === "1d" || selectedRange === "1w") {
        return date.toLocaleString([], {
                month: "short",
                day: "numeric",
                hour: "2-digit",
                minute: "2-digit",
            });
    }
    return date.toLocaleString([], {
            year: "numeric",
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
        });
}

/* CHART CONFIGURATION */

function chartOptions(unit = "") {
    return {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        parsing: false,
        interaction: {
            mode: "nearest",
            axis: "x",
            intersect: false,
        },
        scales: {
            x: {
                type: "linear",
                ticks: {
                    maxTicksLimit: 10,
                    callback(value) {
                        return formatAxisTime(value);
                    },
                },
            },
            y: {
                beginAtZero: true,
                ticks: {
                    callback(value) {
                        return `${value}${unit}`;
                    },
                },
            },
        },
        plugins: {
            legend: {
                position: "bottom",
                labels: {
                    usePointStyle: true,
                    pointStyle: "line",
                    pointStyleWidth: 12,
                    boxWidth: 12,
                    boxHeight: 2,
                    padding: 10,
                    font: {
                        size: 11,
                    },
                },
            },
            tooltip: {
                enabled: true,
                position: "oppositeSide",
                mode: "nearest",
                axis: "x",
                intersect: false,
                padding: 7,
                cornerRadius: 5,
                caretSize: 5,
                boxWidth: 8,
                boxHeight: 8,
                titleFont: {
                    size: 11,
                },
                bodyFont: {
                    size: 11,
                },
                callbacks: {
                    title(items) {
                        if (!items.length) {
                            return "";
                        }
                        return formatTooltipTime(items[0].parsed.x);
                    },
                    label(context) {
                        const label = context.dataset.label ?? "";
                        const value = context.parsed.y;
                        return (
                            `${label}: `
                            + `${Number(value).toLocaleString()}`
                            + unit);
                    },
                },
            },
        },
    };
}

function drawChart(id, datasets, unit = "") {
    if (charts[id]) {
        charts[id].destroy();
    }
    // Keep legend and tooltip ordered alphabetically by node, then metric.
    datasets.sort((a, b) => collator.compare(a.label ?? "", b.label ?? ""));
    const canvas = document.getElementById(id);
    charts[id] = new Chart(canvas, {
            type: "line",
            data: {
                datasets,
            },
            options:
                chartOptions(unit),
        });
}

/* SYSTEM */

function buildSystemGraphs() {
    const cpu = [...graphData.cpu].sort((a, b) => collator.compare(nodeName(a), nodeName(b)));
    const ram = [...graphData.ram].sort((a, b) => collator.compare(nodeName(a), nodeName(b)));
    drawChart("cpu-chart", cpu.map(series => makeDataset(series, nodeName(series))), "%");
    drawChart("ram-chart", ram.map(series => makeDataset(series, nodeName(series))), "%");
}

/* FILTERS */

function populateSelect(id, values, firstLabel) {
    const select = document.getElementById(id);
    const current = select.value;
    select.innerHTML =
        `<option value="all">${firstLabel}</option>`;
    for (const value of values) {
        const option = document.createElement("option");
        option.value = value;
        option.textContent = value;
        select.appendChild(option);
    }
    if ([...select.options].some(option => option.value === current)) {
        select.value = current;
    }
}

function populateFilters() {
    const networkSeries = [...graphData.network_rx, ...graphData.network_tx,];
    populateSelect("network-node", sortedUnique(networkSeries.map(nodeName)), "All nodes");
    populateSelect("network-interface", sortedUnique(networkSeries.map(series => series.interface)), "All interfaces"
    );
    const diskSeries = [...graphData.disk_read, ...graphData.disk_write,];
    populateSelect("disk-node", sortedUnique(diskSeries.map(nodeName)), "All nodes");
    populateSelect("disk-device", sortedUnique(diskSeries.map(series => series.device)), "All disks");
    populateSelect("smart-node", sortedUnique(graphData.smart_temperature.map(nodeName)), "All nodes");
    populateSelect("smart-device", sortedUnique(graphData.smart_temperature.map(series => series.device)), "All disks"
    );
}

function matches(series, node, field, value) {
    if (node !== "all" && nodeName(series) !== node) {
        return false;
    }
    if (value !== "all" && series[field] !== value) {
        return false;
    }
    return true;
}

/* NETWORK */

function buildNetworkGraph() {
    const node = document.getElementById("network-node").value;
    const iface = document.getElementById("network-interface").value;
    const datasets = [];
    for (const series of graphData.network_rx) {
        if (matches(series, node, "interface", iface)) {
            datasets.push(makeDataset(series,
                    `${nodeName(series)} ${series.interface} RX`
                ));
        }
    }
    for (const series of graphData.network_tx) {
        if (matches(series, node, "interface", iface)) {
            datasets.push(makeDataset(series,
                    `${nodeName(series)} ${series.interface} TX`
                ));
        }
    }
    drawChart("network-chart", datasets, " Mbps");
}

/* DISKS */

function diskDatasets(readSeries, writeSeries) {
    const node = document.getElementById("disk-node").value;
    const device = document.getElementById("disk-device").value;
    const datasets = [];
    for (const series of readSeries) {
        if (matches(series, node, "device", device)) {
            datasets.push(makeDataset(series,
                    `${nodeName(series)} ${series.device} Read`
                ));
        }
    }
    for (const series of writeSeries) {
        if (matches(series, node, "device", device)) {
            datasets.push(makeDataset(series,
                    `${nodeName(series)} ${series.device} Write`
                ));
        }
    }
    return datasets;
}

function buildDiskGraphs() {
    drawChart("disk-throughput-chart", diskDatasets(graphData.disk_read, graphData.disk_write), " MB/s");
    drawChart("disk-iops-chart", diskDatasets(graphData.disk_read_iops, graphData.disk_write_iops), " IOPS");
    drawChart("disk-latency-chart", diskDatasets(graphData.disk_read_latency, graphData.disk_write_latency), " ms");
}

/* SMART */

function buildSmartGraph() {
    const node = document.getElementById("smart-node").value;
    const device = document.getElementById("smart-device").value;
    const datasets = graphData.smart_temperature .filter(series => matches(series, node, "device", device)) .map(
                series => makeDataset(series,
                        `${nodeName(series)} ${series.device}`
                    ));
    drawChart("smart-chart", datasets, " °C");
}

/* HEAL */

function buildHealGraph() {
    const datasets = graphData.heal.map(series => makeDataset(series, series.volume));
    drawChart("heal-chart", datasets, " entries");
}

/* BUILD */

function rebuildGraphs() {
    buildSystemGraphs();
    populateFilters();
    buildNetworkGraph();
    buildDiskGraphs();
    buildSmartGraph();
    buildHealGraph();
}

/* LAST UPDATED */

function updateLastUpdated() {
    const refresh = document.getElementById("refresh");
    if (!refresh) {
        return;
    }
    refresh.textContent =
        `Updated ${new Date().toLocaleTimeString()}`;
}

/* DATA LOADING */

async function loadGraphs(range = "5m", start = null, end = null) {
    const status = document.getElementById("graph-status");
    const refresh = document.getElementById("refresh");
    status.textContent = "Loading...";
    if (refresh) {
        refresh.textContent = "Updating...";
    }
    const params = new URLSearchParams();
    params.set("range", range);
    if (range === "custom" && start !== null && end !== null) {
        params.set("start", start);
        params.set("end", end);
    }
    try {
        const response = await fetch(
                `/api/graphs?${params}`
            );
        if (!response.ok) {
            throw new Error(
                `HTTP ${response.status}`
            );
        }
        graphData = await response.json();
        if (graphData.error) {
            throw new Error(graphData.error);
        }
        selectedRange = range;
        rebuildGraphs();
        status.textContent =
            `Step: ${graphData.step}`;
        updateLastUpdated();
    }
    catch (error) {
        status.textContent =
            `Failed: ${error.message}`;
        if (refresh) {
            refresh.textContent = "Update failed";
        }
    }
}

/* RANGE SELECTOR */
document .getElementById("range-selector") .addEventListener("click", event => {
            const button = event.target.closest("button");
            if (!button) {
                return;
            }
            const range = button.dataset.range;
            document .querySelectorAll("#range-selector button") .forEach(item => item.classList.remove("active"));
            button.classList.add("active");
            const custom = document.getElementById("custom-range");
            if (range === "custom") {
                custom.classList.remove("hidden");
                return;
            }
            custom.classList.add("hidden");
            loadGraphs(range);
        });

/* CUSTOM RANGE */
document .getElementById("custom-apply") .addEventListener("click", () => {
            const start = document.getElementById("custom-start").value;
            const end = document.getElementById("custom-end").value;
            if (!start || !end) {
                return;
            }
            loadGraphs("custom", new Date(start).getTime() / 1000, new Date(end).getTime() / 1000);
        });

/* FILTER EVENTS */
for (const id of ["network-node", "network-interface",]) {
    document .getElementById(id) .addEventListener("change", buildNetworkGraph);
}
for (const id of ["disk-node", "disk-device",]) {
    document .getElementById(id) .addEventListener("change", buildDiskGraphs);
}
for (const id of ["smart-node", "smart-device",]) {
    document .getElementById(id) .addEventListener("change", buildSmartGraph);
}

/* START */
loadGraphs("5m");
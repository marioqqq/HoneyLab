from pathlib import Path
import asyncio
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
import time
from prometheus import query, query_range

BASE_DIR = Path(__file__).resolve().parent.parent

FRONTEND_DIR = BASE_DIR / 'frontend'

app = FastAPI(title='GlusterBoard')

def value(result, default=0):
    if not result:
        return default
    return float(result[0]['value'][1])

def series(result):
    return [{**item['metric'], 'value': float(item['value'][1])} for item in result]

# --- Overview Prometheus queries ---

QUERIES = {
    'collectors': 'glusterboard_collector_up',
    'collector_duration': 'glusterboard_collector_duration_seconds',
    'gluster_nodes': 'max(glusterboard_gluster_nodes)',
    'gluster_nodes_connected': 'sum(max by(hostname, uuid) (glusterboard_gluster_node_connected))',
    'gluster_node_connected': 'max by(hostname, uuid) (glusterboard_gluster_node_connected)',
    'volumes': 'max by(volume) (glusterboard_gluster_volume_status)',
    'volume_bricks': 'max by(volume) (glusterboard_gluster_volume_bricks)',
    'bricks_online': 'max by(volume, host, path) (glusterboard_gluster_brick_online)',
    'brick_ports': 'max by(volume, host, path) (glusterboard_gluster_brick_port)',
    'brick_pids': 'max by(volume, host, path) (glusterboard_gluster_brick_pid)',
    'heal_pending': 'max by(volume, host, path) (glusterboard_gluster_heal_pending_entries)',
    'heal_connected': 'max by(volume, host, path) (glusterboard_gluster_heal_connected)',
    'heal_total': 'max by(volume) (glusterboard_gluster_heal_total_pending_entries)',
    'split_supported': 'max by(volume) (glusterboard_gluster_split_brain_supported)',
    'split_detected': 'max by(volume) (glusterboard_gluster_split_brain_detected)',
    'split_files': 'max by(volume) (glusterboard_gluster_split_brain_files)',
    'cpu': 'glusterboard_system_cpu_percent',
    'ram': 'glusterboard_system_ram_usage_percent',
    'ram_total': 'glusterboard_system_ram_total_bytes',
    'ram_used': 'glusterboard_system_ram_used_bytes',
    'swap': 'glusterboard_system_swap_usage_percent',
    'swap_total': 'glusterboard_system_swap_total_bytes',
    'swap_used': 'glusterboard_system_swap_used_bytes',
    'load': 'glusterboard_system_load',
    'uptime': 'glusterboard_system_uptime_seconds',
    'filesystem_usage': 'glusterboard_filesystem_usage_percent{device=~"/dev/sd[a-z]+"}',
    'filesystem_total': 'glusterboard_filesystem_total{device=~"/dev/sd[a-z]+"}',
    'filesystem_used': 'glusterboard_filesystem_used{device=~"/dev/sd[a-z]+"}',
    'filesystem_free': 'glusterboard_filesystem_free{device=~"/dev/sd[a-z]+"}',
    'disk_read': 'glusterboard_disk_read_mb_per_second',
    'disk_write': 'glusterboard_disk_write_mb_per_second',
    'disk_read_iops': 'glusterboard_disk_read_iops',
    'disk_write_iops': 'glusterboard_disk_write_iops',
    'disk_read_latency': 'glusterboard_disk_read_latency_ms',
    'disk_write_latency': 'glusterboard_disk_write_latency_ms',
    'network_up': 'glusterboard_network_interface_up{interface=~"ens.*"}',
    'network_speed': 'glusterboard_network_interface_speed_mbps{interface=~"ens.*"}',
    'network_rx': 'glusterboard_network_receive_mbps{interface=~"ens.*"}',
    'network_tx': 'glusterboard_network_transmit_mbps{interface=~"ens.*"}',
    'network_rx_packets': 'glusterboard_network_receive_packets_total{interface=~"ens.*"}',
    'network_tx_packets': 'glusterboard_network_transmit_packets_total{interface=~"ens.*"}',
    'network_rx_errors': 'glusterboard_network_receive_errors_total{interface=~"ens.*"}',
    'network_tx_errors': 'glusterboard_network_transmit_errors_total{interface=~"ens.*"}',
    'network_rx_drops': 'glusterboard_network_receive_drops_total{interface=~"ens.*"}',
    'network_tx_drops': 'glusterboard_network_transmit_drops_total{interface=~"ens.*"}',
    'smb_online': 'glusterboard_smb_online',
    'nfs_online': 'glusterboard_nfs_online',
    'smart_available': 'glusterboard_smart_available',
    'smart_enabled': 'glusterboard_smart_enabled',
    'smart_health': 'glusterboard_smart_health',
    'smart_temperature': 'glusterboard_smart_temperature_celsius',
    'smart_power_on_hours': 'glusterboard_smart_power_on_hours',
    'smart_reallocated': 'glusterboard_smart_reallocated_sectors',
    'smart_pending': 'glusterboard_smart_pending_sectors',
    'smart_errors': 'glusterboard_smart_uncorrectable_errors',
}

# --- Overview API ---

@app.get('/api/overview')
async def overview():
    names = list(QUERIES)
    results = await asyncio.gather(*[query(QUERIES[name]) for name in names])
    data = dict(zip(names, results))
    total_nodes = int(value(data['gluster_nodes']))
    online_nodes = int(value(data['gluster_nodes_connected']))
    online_bricks = sum((item['value'] for item in series(data['bricks_online'])))
    total_bricks = sum((item['value'] for item in series(data['volume_bricks'])))
    pending_heals = sum((item['value'] for item in series(data['heal_total'])))
    split_brain = sum((item['value'] for item in series(data['split_files'])))
    collectors_ok = all((item['value'] == 1 for item in series(data['collectors'])))
    healthy = (
        total_nodes > 0
        and online_nodes == total_nodes
        and total_bricks > 0
        and online_bricks == total_bricks
        and pending_heals == 0
        and split_brain == 0
        and collectors_ok
    )
    response = {name: series(result) for name, result in data.items()}
    response.update({
        "healthy": healthy,
        "nodes": {"online": int(online_nodes), "total": int(total_nodes)},
        "bricks": {"online": int(online_bricks), "total": int(total_bricks)},
        "pending_heals": int(pending_heals),
        "split_brain": int(split_brain),
    })
    return response

# --- Graph Prometheus queries ---

GRAPH_QUERIES = {
    'cpu': 'glusterboard_system_cpu_percent',
    'ram': 'glusterboard_system_ram_usage_percent',
    'network_rx': 'glusterboard_network_receive_mbps{interface=~"ens.*"}',
    'network_tx': 'glusterboard_network_transmit_mbps{interface=~"ens.*"}',
    'disk_read': 'glusterboard_disk_read_mb_per_second',
    'disk_write': 'glusterboard_disk_write_mb_per_second',
    'disk_read_iops': 'glusterboard_disk_read_iops',
    'disk_write_iops': 'glusterboard_disk_write_iops',
    'disk_read_latency': 'glusterboard_disk_read_latency_ms',
    'disk_write_latency': 'glusterboard_disk_write_latency_ms',
    'smart_temperature': 'glusterboard_smart_temperature_celsius',
    'heal': 'max by(volume) (glusterboard_gluster_heal_total_pending_entries)',
}

# --- Graph time ranges ---

RANGES = {
    '5m': (5 * 60, '5s'),
    '15m': (15 * 60, '5s'),
    '30m': (30 * 60, '10s'),
    '1h': (60 * 60, '15s'),
    '3h': (3 * 60 * 60, '30s'),
    '6h': (6 * 60 * 60, '1m'),
    '12h': (12 * 60 * 60, '2m'),
    '1d': (24 * 60 * 60, '5m'),
    '1w': (7 * 24 * 60 * 60, '30m'),
    '1mo': (30 * 24 * 60 * 60, '2h'),
    '3mo': (90 * 24 * 60 * 60, '6h'),
    '6mo': (180 * 24 * 60 * 60, '12h'),
    '1y': (365 * 24 * 60 * 60, '1d'),
}

# --- Graph helpers ---

def graph_series(result):
    return [{**item['metric'], 'values': [[timestamp, float(value)] for timestamp, value in item['values']]} for item in result]

def custom_step(start: float, end: float):
    duration = end - start
    seconds = max(5, int(duration / 600))
    if seconds < 60:
        return f'{seconds}s'
    minutes = seconds // 60
    if minutes < 60:
        return f'{minutes}m'
    hours = minutes // 60
    if hours < 24:
        return f'{hours}h'
    days = hours // 24
    return f'{days}d'

# --- Graph API ---

@app.get('/api/graphs')
async def graphs(range: str='5m', start: float | None=None, end: float | None=None):
    now = time.time()
    if range == 'custom':
        if start is None or end is None:
            return {'error': 'Custom range requires start and end'}
        query_start = start
        query_end = end
        step = custom_step(query_start, query_end)
    else:
        duration, step = RANGES.get(range, RANGES['5m'])
        query_end = now
        query_start = now - duration
    names = list(GRAPH_QUERIES)
    results = await asyncio.gather(*[query_range(GRAPH_QUERIES[name], query_start, query_end, step) for name in names])
    return {
        "range": range,
        "start": query_start,
        "end": query_end,
        "step": step,
        **{name: graph_series(result) for name, result in zip(names, results)},
    }

# --- Frontend routes ---

@app.get('/graphs')
async def graphs_page():
    return FileResponse(FRONTEND_DIR / 'graphs.html')

app.mount('/static', StaticFiles(directory=FRONTEND_DIR), name='static')

@app.get('/')
async def root():
    return FileResponse(FRONTEND_DIR / 'index.html')
# HoneyLab
<div class="intro" align="center">
    <img src="./img/logo.png" width="25%" alt="logo">
</div>
This repository is a collection of scripts and containers that I use after fresh install. It contains scripts for updating system (desktop / server) and compose files for docker containers that I use.

# ToC
- [Before use](#before-use)
- [Bash Scripts](#bash-scripts)
    - [desktop.sh, server.sh](#desktopsh-serversh)
    - [rsync.sh](#rsyncsh)
    - [nvidia_docker.sh](#nvidia_dockersh)
- [Docker](#docker)
- [Misc](#misc)

# Before use
Before using this repo you may need to install git.
```bash
sudo apt install git -y
```

# Bash Scripts
This repo currently contains 4 scripts:
- desktop.sh
- server.sh
- rsync.sh
- nvidia_docker.sh

To run the scripts, you need to make them executable:
```bash
chmod +x ___.sh
```

## desktop.sh, server.sh
Scripts will install `dialog` package for menu. Then it will perform update and upgrade of the system. After that, it will install packages that you select in menu. At the end, it will remove unnecessary packages as well as `dialog`, clean the system and reboot.

List of packages that can be installed:
| desktop.sh           | server.sh   |
|----------------------|-------------|
| - Remove LibreOffice | - Docker**  |
| - Browser Swap*      | - Avahi     |
| - Docker**           | - Nano      |
| - VS Code            | - ArgoneOne |
| - DBeaver            | - rsync     |
| - FileZilla          |             |
| - Discord            |             |
| - Wireguard          |             |
| - Thunderbird        |             |

*Browser Swap removes Firefox and installs Brave Browser.<br>
**Docker installs docker and docker-compose.

## rsync.sh
This script uses `rsync` command to sync the repo (or any files) to external location (in this case NAS). To use it, you need to copy (move or rename) `example.env` to `.env` and modify it.

## nvidia_docker.sh
If you have NVIDIA GPU drivers installed, you can use this script to install NVIDIA Container Toolkit. It will also install NVIDIA drivers for docker. Test if drivers are installed with `nvidia-smi` command. If not, please refer to [NVIDIA drivers installation](https://ubuntu.com/server/docs/nvidia-drivers-installation). Then run the script. Verify the installation with `ddocker run --gpus all nvidia/cuda:11.5.2-base-ubuntu20.04 nvidia-smi`.

# Docker
This repo contains docker-compose files that are separated into:
- [cloud](/docker/cloud/) - contains containers that are accessible from the internet
    - [grav](https://hub.docker.com/r/linuxserver/grav)
    - [minecraft](https://hub.docker.com/r/itzg/minecraft-server)
- [management-client](/docker/management-client/) - contains containers that are used for managing the client
    - [portainer-agent](https://hub.docker.com/r/portainer/agent)
    - [watchtower](https://hub.docker.com/r/containrrr/watchtower)
- [management-server](/docker/management-server/) - contains containers that are used for managing the server
    - [portainer](https://hub.docker.com/r/portainer/portainer-ce)
    - [watchtower](https://hub.docker.com/r/containrrr/watchtower)
- [media*](/docker/media/) - contains containers that are used for media
    - [bazarr](https://hub.docker.com/r/linuxserver/bazarr)
    - [lidarr](https://hub.docker.com/r/linuxserver/lidarr)
    - [plex](https://hub.docker.com/r/linuxserver/plex)
    - [prowlarr](https://hub.docker.com/r/linuxserver/prowlarr)
    - [radarr](https://hub.docker.com/r/linuxserver/radarr)
    - [transmission](https://hub.docker.com/r/linuxserver/transmission)
- [misc](/docker/misc/) - contains containers that are not used, but are helpful
    - [node-red](https://hub.docker.com/r/nodered/node-red)
    - [octoprint](https://hub.docker.com/r/octoprint/octoprint)
- [monitoring](/docker/monitoring/) - contains containers that are used for monitoring
    - [grafana](https://hub.docker.com/r/grafana/grafana)
    - [prometheus](https://hub.docker.com/r/prom/prometheus)
    - [cadvisor](https://hub.docker.com/r/google/cadvisor)
    - [graphite_exporter](https://hub.docker.com/r/prom/graphite-exporter)
    - [node_exporter](https://hub.docker.com/r/prom/node-exporter)
    - [nvidia_smi_exporter](https://hub.docker.com/r/utkuozdemir/nvidia_gpu_exporter)
- [networking*](/docker/networking/) - contains containers that are used for networking
    - [duckdns](https://hub.docker.com/r/linuxserver/duckdns)
    - [nginx-proxy-manager](https://hub.docker.com/r/jc21/nginx-proxy-manager)
    - [wireguard](https://hub.docker.com/r/linuxserver/wireguard)
- [personal*](/docker/personal/) - contains containers that are used for personal use
    - [homepage](https://hub.docker.com/r/linuxserver/homepage)
    - [vaultwarden](https://hub.docker.com/r/vaultwarden/server)

Composes with * need .env file.

# Misc
If timezone is wrong, set it with:
```bash
# List available timezones
timedatectl list-timezones

# Set timezone
sudo timedatectl set-timezone ___
```

Change hostname:
```bash
sudo hostnamectl set-hostname ___
```
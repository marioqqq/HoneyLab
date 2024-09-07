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
- [TODO](#todo)

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
This repo contains docker-compose files for following containers:
- [bazarr](https://hub.docker.com/r/linuxserver/bazarr)
- [duckdns](https://hub.docker.com/r/linuxserver/duckdns)
- [grav](https://hub.docker.com/r/linuxserver/grav)
- [mariadb](https://hub.docker.com/r/linuxserver/mariadb)
- [nginx-proxy-manager](https://hub.docker.com/r/jc21/nginx-proxy-manager)
- [node-red](https://hub.docker.com/r/nodered/node-red)
- [octoprint](https://hub.docker.com/r/octoprint/octoprint)
- [pihole](https://hub.docker.com/r/pihole/pihole)
- [portainer](https://hub.docker.com/r/portainer/portainer-ce)
- [portainer-agent](https://hub.docker.com/r/portainer/agent)
- [prowlarr](https://hub.docker.com/r/linuxserver/prowlarr)
- [radaarr](https://hub.docker.com/r/linuxserver/radarr)
- [transmission](https://hub.docker.com/r/linuxserver/transmission)
- [vaultwarden](https://hub.docker.com/r/vaultwarden/server)
- [watchtower](https://hub.docker.com/r/containrrr/watchtower)
- [wireguard](https://hub.docker.com/r/linuxserver/wireguard)

Volumes needed for containers are defined in [compose](/docker/docker-compose.yaml). Each container that needs additional config has `example.env` present in its folder. You need to copy (move or rename) it to `.env` and modify it.

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

# TODO
Containers:
- [ ] lidarr
- [ ] prometheus with grafana and configs - need something better, or be better :)
- [x] wordpress (or alternative)
- [ ] script for drivers
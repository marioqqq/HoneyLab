# HoneyLab
<div class="intro" align="center">
    <img src="./img/logo.png" width="25%" alt="logo">
</div>
This repository is a collection of scripts and containers that I use after fresh install. It contains scripts for updating system (desktop / server) and compose files for docker containers that I use.

# ToC
- [Bash Scripts](#bash-scripts)
    - [desktop.sh, server.sh](#desktopsh-serversh)
    - [rsync.sh](#rsyncsh)
- [Docker](#docker)
- [TODO](#todo)

# Bash Scripts
This repo currently contains 3 scripts:
- desktop.sh
- server.sh
- rysnc.sh

First two scipts are used after fresh install of Debian based system. They update the system and install packages that you select in menu. The third script is used to sync this repo to NAS.

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

*Browser Swap removes Firefox and installs Brave Browser.<br>
**Docker installs docker and docker-compose.

## rsync.sh
This script uses `rsync` command to sync the repo (or any files) to external location (in this case NAS). To use it, you need to copy (move or rename) `example.env` to `.env` and modify it.

# Docker
This repo contains docker-compose files for following containers:
- [bazarr](https://hub.docker.com/r/linuxserver/bazarr)
- [duckdns](https://hub.docker.com/r/linuxserver/duckdns)
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

# TODO
Containers:
- [ ] lidarr
- [ ] prometheus with grafana and configs - need something better, or be better :)
- [x] wordpress (or alternative)
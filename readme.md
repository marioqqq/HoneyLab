# HoneyLab
<div class="intro" align="center">
    <img src="./img/logo.png" width="25%" alt="logo">
</div>

This repository contains scripts and docker containers for each machine / VM after fresh install. It is spread across multiple folders, depending on the purpose of the machine.

<!-- <div class="intro" align="center">
    <img src="./img/services.svg" width="75%" alt="services">
</div>

*[Icons](https://github.com/free-icons/free-icons) -->

# Before use
Before using this repo you may need to install git.
```bash
sudo apt install git -y
```

# PC-Personal postInstall.sh
To run script, you need to make it executable:
```bash
chmod +x postInstall.sh
```
Script will perform update and upgrade of the system, sets user do use docker without `sudo` and sets timezone. After that, it will install / remove following packages:

- ❌ LibreOffice
- Brave browser
- ❌ Firefox
- Docker
- Docker-compose
- VS Code
- DBeaver
- FileZilla
- Discord
- Wireguard
- Thunderbird

# Adguard home
[Adguard home blacklists](https://firebog.net/)

# Containers
- SRV-Management
    - Portainer
    - Watchtower
    - Adguard home
    - Nginx Proxy Manager
    - Rustdesk
- SRV-Media
    - Portainer agent
    - Watchtower
    - Bazarr
    - Immich
    - Lidarr
    - Plex
    - Postgres
    - Prowlarr
    - Radarr
    - Redis
    - Transmission
- SRV-Personal
    - Portainer agent
    - Watchtower
    - Docmost
    - Grafana
    - Homepage
    - MariaDB
    - NocoDB
    - Postgres
    - Redis
    - Vaultwarden
- SRV-VPN
    - Portainer agent
    - Watchtower
    - DuckDNS
    - Tailscale
    - Wireguard
- SRV-Cloud
    - Watchtower
    - Headscale
    - Kasm
    - Minecraft
    - Nginx Proxy Manager
- Misc
    - Grav
    - Ignition gateway
    - Node-Red
    - Octoprint
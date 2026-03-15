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
- SRV-Cloud
    - Watchtower
    - Gotify
    - Headscale
    - Kimai
    - MySQL
    - Nginx Proxy Manager
    - Omni tools
- SRV-Management
    - Portainer
    - Watchtower
    - Adguard home
    - Linux update dashboard
    - Nginx Proxy Manager
    - Rackpeek
    - Uptime-kuma
- SRV-Arr
    - Portainer agent
    - Watchtower
    - Bazarr
    - Prowlarr
    - Radarr
    - Transmission with VPN
- SRV-Media
    - Portainer agent
    - Watchtower
    - Immich
    - Plex
    - Postgres
    - Redis
- SRV-Personal
    - Portainer agent
    - Watchtower
    - Grafana
    - Homepage
    - MariaDB
    - NocoDB
    - Vaultwarden
- SRV-VPN
    - Portainer agent
    - Watchtower
    - Tailscale
- SRV-NUT
    - Portainer agent
    - Watchtower
    - Adguard home
    - Nutify
    - Upsnap
    - Upswake
- Misc
    - Docmost
    - Postgres
    - Redis
    - DuckDNS
    - Grav
    - Ignition gateway
    - Kasm
    - Minecraft
    - Node-Red
    - Octoprint
    - Rustdesk
    - Transmission
    - Windows
    - Wireguard
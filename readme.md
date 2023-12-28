# HoneyLab
<div class="intro" align="center">
    <img src="./img/logo.png" width="25%" alt="logo">
</div>
This repository is a collection of services that I use. Purpose of this repository is to make it easier to install and configure these services after fresh install. I'm using Raspberry Pi 4 with 8GB of RAM and Raspberry Pi OS Lite (64-bit) released 11.12.2023. Currently few of my services are running at my NAS, but due to higher power consumption I decided to move them to Raspberry Pi.

## ToC
- [1. My network configuration](#1-my-network-configuration)
- [2. To begin](#2-to-begin)
    - [2.1 Post Installation Update](#21-post-installation-update)
    - [2.2 Install Services](#22-install-services)
        - [2.2.1 Docker](#221-docker)
        - [2.2.2 Docker-Compose](#222-docker-compose)
        - [2.2.3 PiVPN](#223-pivpn)
        - [2.2.4 ArgonOne](#224-argonone)
    - [2.3 Run Docker-Compose](#23-run-docker-compose)
    - [2.4 ArgonOne Configuration](#24-argonone-configuration)
- [3. To end](#3-to-end)
- [TODO](#todo)

## 1. My configuration
<div class="network" align="center">
    <img src="./img/network.drawio.png" width="50%" alt="network">
</div>
I'm not a network expert, so I don't know if this is a good representation of my network. After all services are running, I will update this configuration.

## 2. To begin
`run.sh` consists of Post Installation Update, Install Sercices, Run Docker-Compose and ArgonOne Configuration. To run this script, it is necessary to execute `chmod +x run.sh`. After that, you can run the script with `./run.sh`.
After starting it will check if `dialog` is installed. If not it will install it using `sudo apt install dialog -y`. After that, it will show a menu.
<div class="menu" align="center">
    <img src="./img/menu.png" width="50%" alt="menu">
</div>

### 2.1 Post Installation Update
This will execute `sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y`

### 2.2 Install Services
Currently, there are 4 services available. But PiVPN is not working yet. More services will be added soon.
<div class="services" align="center">
    <img src="./img/services.png" width="50%" alt="services">
</div>

#### 2.2.1 Docker
Checks if already installed. If not it will execute `sudo apt install docker.io -y`

#### 2.2.2 Docker-Compose
Checks if already installed. If not it will execute `sudo apt install docker-compose -y`

#### 2.2.3 PiVPN
Currently not working.

#### 2.2.4 ArgonOne
It will check if directory `/etc/argon` exists. If not it will execute `curl https://download.argon40.com/argon1.sh | bash`. Not sure if this is the best way to find if ArgonOne is installed.

### 2.3 Run Docker-Compose
Currently not working.

### 2.4 ArgonOne Configuration
It will run Argon Configuration tool.
<div class="argon" align="center">
    <img src="./img/argon.png" width="50%" alt="argon">
</div>

## 3. To end
When you are done, you can exit the menu with `Cancel`. After that, you will be asked if you want to reboot.
<div class="reboot" align="center">
    <img src="./img/reboot.png" width="50%" alt="reboot">
</div>

## TODO
- [x] Make `run.sh` running at least partially
- [x] Run few docker containers
- [x] Make `readme.md`
- [ ] Redo network diagram
- [ ] Make service diagram
- [ ] Finish `run.sh`
- [ ] Add additional services
- [ ] Make Docker-Compose work with option to edit variables
- [ ] Run all services
- [ ] Make additional `readme.md` for each container
- [ ] Finish `readme.md`
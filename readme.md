# HoneyLab
<div class="intro" align="center">
    <img src="./img/logo.png" width="25%" alt="logo">
</div>

This repository contains scripts and docker containers for each machine / VM after fresh install. It is spread across multiple folders, depending on the purpose of the machine.

<div class="intro" align="center">
    <img src="./img/services.svg" width="75%" alt="services">
</div>

*[Icons](https://github.com/free-icons/free-icons)


# Before use
Before using this repo you may need to install git.
```bash
sudo apt install git -y
```

# Bash Scripts
To run the scripts, you need to make them executable:
```bash
chmod +x ___.sh
```
Script will perform update and upgrade of the system, sets user do use docker without `sudo` and sets timezone. After that, it will install following packages:

## PC-Personal postInstall.sh
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

## SRV-Cloud postInstall.sh
- nano
- docker
- docker-compose
- set timezone

## SRV-DEV postInstall.sh
- nano
- docker
- docker-compose
- set timezone

## SRV-Managemet postInstall.sh
- nano
- docker
- docker-compose
- set timezone

## SRV-Media postInstall.sh
- nano
- docker
- docker-compose
- set timezone

## SRV-Media nvidiaDocker.sh
- nvidia container toolkit
- set nvidia runtime for docker

If you have NVIDIA GPU drivers installed, you can use this script to install NVIDIA Container Toolkit. It will also install NVIDIA drivers for docker. Test if drivers are installed with `nvidia-smi` command. If not, please refer to [NVIDIA drivers installation](https://ubuntu.com/server/docs/nvidia-drivers-installation). Then run the script. Verify the installation with `ddocker run --gpus all nvidia/cuda:11.5.2-base-ubuntu20.04 nvidia-smi`.

## SRV-Personal postInstall.sh
- nano
- docker
- docker-compose
- set timezone

## SRV-VPN postInstall.sh
Script will perform update and upgrade of the system, sets user do use docker without `sudo`. After that, it will install following packages:
- docker
- docker-compose
- #ArgonOne
In docs you can find instructions on how to install PiVPN your for Raspberry Pi.

# Machines / VMS docs
Docs for containers and services on each machine / VM:
- [SRV-Cloud](/SRV-Cloud/readme.md)
- [SRV-Management](/SRV-Management/readme.md)
- [SRV-Media](/SRV-Media/readme.md)
- [SRV-Personal](/SRV-Personal/readme.md)
- [SRV-VPN](/SRV-VPN/readme.md)

# Misc
Change hostname:
```bash
sudo hostnamectl set-hostname ___
```
#!/bin/bash

# Post install updates and drivers
postInstall(){
    clear
    sudo apt update && sudo apt upgrade -y
    sudo ubuntu-drivers install
}

# Install and setup services
installServices(){
    sudo apt install nano -y
    sudo apt install docker.io
    mkdir -p ~/.docker/cli-plugins/
    curl -SL https://github.com/docker/compose/releases/download/v2.31.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    sudo usermod -aG docker $USER
    sudo timedatectl set-timezone Europe/Bratislava
    sudo apt autoremove -y
    sudo reboot
}

main(){
    postInstall
    installServices
}

main
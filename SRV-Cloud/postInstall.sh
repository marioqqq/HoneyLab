#!/bin/bash

# Post install updates
postInstall(){
    clear
    apt update && sudo apt upgrade -y
}

# Install and setup services
installServices(){
    apt install docker.io -y
    apt install docker-compose -y
    apt autoremove -y
    reboot
}

main(){
    postInstall
    installServices
}

main
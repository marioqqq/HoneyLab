#!/bin/bash

# Post install updates
postInstall(){
    clear
    sudo apt update && sudo apt upgrade -y
}

# Install and setup services
installServices(){
    sudo apt install docker.io -y
    sudo apt install docker-compose -y
    sudo usermod -aG docker $USER
    # curl https://download.argon40.com/argon1.sh | bash
    sudo apt autoremove -y
    sudo reboot
}

main(){
    postInstall
    installServices
}

main
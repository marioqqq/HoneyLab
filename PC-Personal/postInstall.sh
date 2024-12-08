#!/bin/bash

# Post install updates
postInstall(){
    clear
    sudo apt update && sudo apt upgrade -y
}

# Install and setup services
installServices(){
    sudo apt remove --purge "libreoffice*" -y
    sudo apt clean
    sudo apt install curl -y
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt update
    sudo apt install brave-browser -y
    sudo apt remove firefox -y
    sudo apt install docker.io -y
    sudo apt install docker-compose -y
    sudo usermod -aG docker $USER
    sudo apt install code -y
    sudo add-apt-repository ppa:serge-rider/dbeaver-ce
    sudo apt update
    sudo apt install dbeaver-ce -y
    sudo apt install filezilla -y
    sudo apt install discord -y
    sudo apt install wireguard-tools -y
    sudo apt install thunderbird -y
    sudo apt autoremove -y
    sudo reboot
}

main(){
    postInstall
    installServices
}

main
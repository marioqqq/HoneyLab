#!/bin/bash

# Post install updates
postInstall(){
    clear
    sudo apt update && sudo apt upgrade -y
    sudo ubuntu-drivers install
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
    sudo apt install snap -y
    sudo snap remove firefox
    sudo apt install docker.io -y
    mkdir -p ~/.docker/cli-plugins/
    curl -SL https://github.com/docker/compose/releases/download/v2.31.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    sudo usermod -aG docker $USER
    sudo snap install --classic code
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
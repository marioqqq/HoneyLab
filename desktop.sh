#!/bin/bash

# Post install updates and drivers
postInstall(){
    clear
    sudo apt update && apt upgrade -y
}

# Install services
installServices(){
    # Define services
    local services=(
        "Remove LibreOffice" 
        "Browser Swap"
        "Docker"
        "VS Code"
        "DBeaver"
        "Filezilla"
        "Discord"
        "Wireguard"
        "Thunderbird"
    )

    # Create checklist arguments
    local checklistArgs=()
    for service in "${services[@]}"; do
        checklistArgs+=("$service" "" "off")
    done

    # Create checklist
    local selectedApps=$(dialog --title "Services Installation" --checklist \
        "Choose the services you want to install\nPress 'Space' to select" 20 78 6 \
        "${checklistArgs[@]}" 3>&1 1>&2 2>&3)

    clear

    # Get exit status
    local exitStatus=$?

    # Check if the user exited the menu or not
    if [ $exitStatus = 0 ]; then
        # Check if any services were selected
        if [ ! -z "$selectedApps" ]; then
            # Split selected apps into an array
            IFS=" " read -r -a selected <<< "$selectedApps"
            # Install selected apps
            for app in "${selected[@]}"; do
                case $app in
                    "Remove LibreOffice")
                        sudo apt remove --purge "libreoffice*" -y
                        sudo apt clean
                        ;;
                    "Browser Swap")
                        sudo apt install curl -y
                        sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
                        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
                        sudo apt update
                        sudo apt install brave-browser -y
                        sudo apt remove firefox -y
                        ;;
                    "Docker")
                        sudo apt install docker.io docker-compose -y
                        sudo usermod -aG docker $USER
                        ;;
                    "VS Code")
                        sudo apt install code -y
                        ;;
                    "DBeaver")
                        sudo add-apt-repository ppa:serge-rider/dbeaver-ce
                        sudo apt update
                        sudo apt install dbeaver-ce -y
                        ;;
                    "Filezilla")
                        sudo apt install filezilla -y
                        ;;
                    "Discord")
                        sudo apt install discord -y
                        ;;
                    "Wireguard")
                        sudo apt install wireguard-tools -y
                        ;;
                    "Thunderbird")
                        sudo apt install thunderbird -y
                        ;;
                    *) echo "Unknown option: $app";;
                esac
            done
            clear
        else
            clear
            echo "No applications selected or installation canceled by user."
            sleep 2
        fi
    else
        clear
        echo "An unexpected error occurred (exit status: $exitStatus)."
        sleep 2
    fi
}

menu(){
    clear
    # Install dialog for menu
    sudo apt install dialog -y
    # Perform updates
    postInstall
    # Install services
    installServices
    # Remove dialog and reboot
    sudo apt remove dialog -y
    sudo apt autoremove -y
    sudo reboot
}

menu
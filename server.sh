#!/bin/bash

# Post install updates and drivers
postInstall(){
    clear
    sudo apt update && sudo apt upgrade -y
    sudo ubuntu-drivers install 
}

# Install services
installServices(){
    # Define services
    local services=(
        "Docker" 
        "Avahi"
        "Nano"
        "ArgoneOne"
        "rsync"
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
                    "Docker")
                        sudo apt install docker.io docker-compose -y
                        sudo usermod -aG docker $USER
                        ;;
                    "Avahi")
                        sudo apt install avahi-daemon avahi-utils -y
                        ;;
                    "Nano")
                        sudo apt install nano -y
                        ;;
                    "ArgonOne")
                        curl https://download.argon40.com/argon1.sh | bash
                        ;;
                    "rsync")
                        sudo apt install rsync -y
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

# Main menu
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
#!/bin/bash

# Post install updates
postInstallUpdates(){
    clear
    echo "Updating package lists..."
    sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
    clear
    echo "Package lists updated."
    sleep 2
}

# Install services
installServicesFunction(){
    # Define services
    local services=(
        "Docker" "Container-based application deployment tool"
        "Docker-Compose" "Multi-container Docker setup tool"
        "PiVPN" "Simple VPN setup and management software"
        "ArgonOne" "Installs fan and power button control*"
    )

    # Create checklist arguments
    local checklistArgs=()
    for ((i = 0; i < ${#services[@]}; i+=2)); do
        checklistArgs+=("${services[i]}" "${services[i+1]}" "off")
    done

    # Create checklist
    local selectedApps=$(dialog --title "Services Installation" --checklist \
        "Choose the services you want to install\nPress 'Space' to select\n* - After all installations it is recommended to reboot the device" 20 78 5 \
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
                        if ! dpkg -l | grep -q "docker.io"; then
                            sudo apt install docker.io -y
                        else
                            echo "Docker already installed."
                            sleep 2
                        fi;;
                    "Docker-Compose")
                        if ! dpkg -l | grep -q "docker-compose"; then
                            sudo apt install docker-compose -y
                        else
                            echo "Docker-Compose already installed."
                            sleep 2
                        fi;;
                    "PiVPN")
                        if ! dpkg -l | grep -q "openvpn"; then
                            curl -L https://install.pivpn.io | bash
                        else
                            echo "Enter name for the .opvn file:"
                            read -r name
                            pivpn add -n "$name"
                            sudo mv /etc/openvpn/easy-rsa/pki/"$name".ovpn /home/"$USER"/
                            sudo chown "$USER":"$USER" /home/"$USER"/"$name".ovpn
                            echo "The .opvn file moved to home directory."
                            sleep 2
                        fi;;
                    "ArgonOne") 
                        if ! [ -d "/etc/argon" ]; then
                                curl https://download.argon40.com/argon1.sh | bash
                            else
                                argonone-config
                            fi;;
                        *) echo "Unknown option: $app";;
                esac
            done
            clear
            echo "Installation process complete."
            sleep 2
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
    # Loop until the user exits the menu
    while true; do
        # Define menu options
        local menuOptions=(
            ["1"]="Post Installation Updates"
            ["2"]="Install Services"
            ["3"]="Run Docker-Compose"
            ["4"]="ArgonOne Configuration (if installed)"
        )

        # Create menu
        CHOICE=$(dialog --title "Menu" \
                --menu "Choose one option:" 15 50 3 \
                "1" "${menuOptions["1"]}" \
                "2" "${menuOptions["2"]}" \
                "3" "${menuOptions["3"]}" \
                3>&1 1>&2 2>&3)

        # Close dialog
        clear

        # Get exit status
        local exitStatus=$?

        # Check if the user exited the menu or not
        if [ $exitStatus = 0 ]; then
            # Check which option was selected
            if [ ! -z "$CHOICE" ]; then
                    # Run the command associated with the menu option
                    case $CHOICE in
                        "1")
                            # Run post install updates
                            postInstallUpdates;;
                        "2")
                            # Run install services
                            installServicesFunction;;
                        "3")
                            # Run docker-compose
                            echo "Docker Compose" # Future implementation
                            ;;
                        *)
                            echo "No valid option selected"
                            ;;
                    esac
            else
                break
            fi
        else
            echo "An unexpected error occurred (exit status: $exitStatus)."
        fi
    done
}

# Start
if ! dpkg -l | grep -q "dialog"; then
    sudo apt install dialog -y
fi

# Main
menu

# Close
if dialog --title "Exit and reboot" --yesno "Do you want to reboot?" 8 40; then
    sudo reboot
else
    clear
    echo "Canceled by user."
fi
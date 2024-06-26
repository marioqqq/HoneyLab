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
        "Docker" 
        "Docker-Compose"
        "Avahi"
        "Nano"
        "ArgoneOne"
    )

    # Create checklist arguments
    local checklistArgs=()
    for service in "${services[@]}"; do
        checklistArgs+=("$service" "" "off")
    done

    # Create checklist
    local selectedApps=$(dialog --title "Services Installation" --checklist \
        "Choose the services you want to install\nPress 'Space' to select" 20 78 5 \
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
                            sudo usermod -aG docker $USER
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
                    "Avahi")
                        if ! dpkg -l | grep -q "avahi-daemon"; then
                            sudo apt install avahi-daemon avahi-utils -y
                        else
                            echo "Avahi already installed."
                            sleep 2
                        fi;;
                    "Nano")
                        if ! dpkg -l | grep -q "nano"; then
                            sudo apt install nano -y
                        else
                            echo "Nano already installed."
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
        )

        # Create menu
        CHOICE=$(dialog --title "Menu" \
                --menu "Choose one option:" 15 50 2 \
                "1" "${menuOptions["1"]}" \
                "2" "${menuOptions["2"]}" \
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
else
    menu
fi
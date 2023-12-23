#!/bin/bash

postInstallUpdates(){
    clear
    echo "Updating package lists..."
    sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
    echo "Package lists updated."
}

installServicesFunction(){
    
    local services=(
        "Docker" "Container-based application deployment tool"
        "Docker-Compose" "Multi-container Docker setup tool"
        "PiVPN" "Simple VPN setup and management software*"
        "ArgonOne" "Installs fan and power button control**"
    )

    # Prepare the checklist arguments
    local checklistArgs=()
    for ((i = 0; i < ${#services[@]}; i+=2)); do
        checklistArgs+=("${services[i]}" "${services[i+1]}" "off")
    done

    # Show the checklist using dialog
    local selectedApps=$(dialog --title "Services Installation" --checklist \
        "Choose the services you want to install\n* - Currently not used\n** - After all installations it recommend to reboot the device" 20 78 5 \
        "${checklistArgs[@]}" 3>&1 1>&2 2>&3)

    clear

    local exitStatus=$?

    if [ $exitStatus = 0 ]; then
        if [ ! -z "$selectedApps" ]; then
            IFS=" " read -r -a selected <<< "$selectedApps"

            # Installation commands
            for app in "${selected[@]}"; do
                case $app in
                    "Docker") sudo apt install docker.io -y;;
                    "Docker-Compose") sudo apt install docker-compose -y;;
                    "PiVPN") echo "Currently not used";;
                    "ArgonOne") echo 'Rebooting';;
                    *) echo "Unknown option: $app";;  # Default case for debugging
                esac
            done
            echo "Installation process complete."
        else
            echo "No applications selected or installation canceled by user."
        fi
    else
        echo "An unexpected error occurred (exit status: $exitStatus)."
    fi

}

# installServicesFunction
# sudo apt install dialog -y

menu(){
    while true; do
        # Define menu options
        # declare -A menuOptions
        local menuOptions=(
            ["1"]="Post Installation Updates"
            ["2"]="Install Services"
            ["3"]="Run Docker-Compose"
        )

        # Create menu
        CHOICE=$(dialog --title "Menu Title" \
                --menu "Choose one option:" 15 50 3 \
                "1" "${menuOptions["1"]}" \
                "2" "${menuOptions["2"]}" \
                "3" "${menuOptions["3"]}" \
                3>&1 1>&2 2>&3)

        # Close dialog
        clear

        local exitStatus=$?

        if [ $exitStatus = 0 ]; then
            if [ ! -z "$CHOICE" ]; then
                # Confirmation dialog
                if dialog --title "Confirmation" --yesno "Do you want to proceed with option ${menuOptions[$CHOICE]}?" 8 40; then
                    # Act on the choice
                    case $CHOICE in
                        "1")
                            postInstallUpdates;;
                        "2")
                            installServicesFunction;;
                        "3")
                            echo "Docker Compose"
                            # Your code for Option 3
                            ;;
                        *)
                            echo "No valid option selected"
                            ;;
                    esac
                else
                    # User chose 'No', return to menu
                    continue
                fi
            else
                echo "Canceled by user."
                break
            fi
        else
            echo "An unexpected error occurred (exit status: $exitStatus)."
        fi
    done
}

## check if dialog is installed

sudo apt install dialog -y
menu
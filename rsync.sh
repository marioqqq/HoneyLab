#!/bin/bash

# Source the environment file
source .env

# Check if NAS is reachable
ping -c 1 $NAS_IP &> /dev/null

if [ $? -eq 0 ]; then
    echo "NAS is reachable. Proceeding with backup..."

    # Create the mount folder
    mkdir -p $MOUNT

    # Mount the NAS share
    sudo mount -t cifs -o username=$USERNAME,password=$PASSWORD $SHARE $MOUNT

    if [ $? -eq 0 ]; then
        echo "NAS mounted successfully."

        # Perform backup using rsync
        rsync -r --delete $SOURCE $DESTINATION

        if [ $? -eq 0 ]; then
            echo "Backup completed successfully."
        else
            echo "Backup failed."
        fi

        # Unmount the NAS share
        sudo umount $MOUNT

        if [ $? -eq 0 ]; then
            echo "NAS unmounted successfully."
        else
            echo "Failed to unmount the NAS."
        fi
    else
        echo "Failed to mount the NAS."
    fi
else
    echo "NAS is not reachable. Backup aborted."
fi

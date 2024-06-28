#!/bin/bash

# Source the environment file
source .env

# Check if NAS is reachable
ping -c 1 $NAS_IP &> /dev/null

if [ $? -eq 0 ]; then
    echo "NAS is reachable. Proceeding with backup..."

    # Mount the NAS share
    sudo mount -t cifs -o username=$NAS_USER,password=$NAS_PASS $NAS_SHARE $MOUNT_DIR

    if [ $? -eq 0 ]; then
        echo "NAS mounted successfully."

        # Perform backup using rsync
        rsync -r --delete $BACKUP_SOURCE $BACKUP_DEST

        if [ $? -eq 0 ]; then
            echo "Backup completed successfully."
        else
            echo "Backup failed."
        fi

        # Unmount the NAS share
        sudo umount $MOUNT_DIR

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

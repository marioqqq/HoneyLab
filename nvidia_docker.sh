#!/bin/bash

# NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Update and install NVIDIA Container Toolkit
sudo apt update
sudo apt install nvidia-container-toolkit -y

# Configure NVIDIA Container Toolkit
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker
sudo systemctl restart docker

# Clean up and reboot
sudo apt autoremove -y
sudo reboot
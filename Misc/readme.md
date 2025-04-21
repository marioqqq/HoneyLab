# nvidiaDocker.sh
- nvidia container toolkit
- set nvidia runtime for docker

If you have NVIDIA GPU drivers installed, you can use this script to install NVIDIA Container Toolkit. It will also install NVIDIA drivers for docker. Test if drivers are installed with `nvidia-smi` command. If not, please refer to [NVIDIA drivers installation](https://ubuntu.com/server/docs/nvidia-drivers-installation). Then run the script. Verify the installation with `ddocker run --gpus all nvidia/cuda:11.5.2-base-ubuntu20.04 nvidia-smi`.
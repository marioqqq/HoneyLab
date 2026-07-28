## Nvidia GPU passthrough
Edit grub `nano /etc/default/grub` and change:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet"

-- TO --

GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt modprobe.blacklist=nouveau,nvidia,nvidiafb,nvidia-gpu initcal>
```
Run `update-grub`

Then edit blaclist `nano /etc/modprobe.d/pve-blacklist.conf` to this:
```bash
blacklist nvidiafb
```

Lastly `reboot`
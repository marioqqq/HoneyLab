## GPU passthrough
Edit grub `nano /etc/default/grub` and change:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet"

-- TO --

GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on pcie_acs_override=downstream,multifunction video=efifb:eek:ff"
```
Run `update-grub`

Edit modules `nano /etc/modules` and add:

```bash
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

Then edit blaclist `nano /etc/modprobe.d/pve-blacklist.conf` to this:
```bash
blacklist nvidiafb
blacklist nvidia
blacklist radeon
blacklist nouveau
```

Lastly `reboot`
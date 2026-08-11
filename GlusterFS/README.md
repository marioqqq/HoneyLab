# Setup GlusterFS
Change variables in vars/ceph.yaml, inventory/hosts.yaml and run the playbooks:

```bash
ansible-playbook -K -i inventory/hosts.yaml playbooks/01-prepare-nodes.yaml
ansible-playbook -K -i inventory/hosts.yaml playbooks/02-deploy-glusterfs.yaml
ansible-playbook -K -i inventory/hosts.yaml playbooks/03-mount-volume.yaml
```

If you want to run SMB/NFS on top of GlusterFS, set `smb_enabled: true` or `nfs_enabled: true` and tweak the variables in `vars/gluster.yaml` and you can run the following playbook:

```bash
ansible-playbook -K -i inventory/hosts.yaml playbooks/04-smb-nfs.yaml
```

# Manual GlusterFS Setup
Steps to manually setup GlusterFS on all nodes. Although GlusterFS dosn't require a master node, I dedicated one node as master to manage the cluster.


```bash
- All nodes
sudo apt install glusterfs-server -y
sudo systemctl start glusterd
sudo systemctl enable glusterd

- Master
sudo gluster peer probe [all slave IPs]
sudo gluster peer status
sudo gluster pool list

- All nodes (assuming fresh disks, otherwise you need to clean the disks first)
sudo mkfs.ext4 /dev/sdX
sudo mkdir -p /pool/disk1

blkid /dev/sdX # Get UUID of the disk
sudo nano /etc/fstab

UUID=<UUID> /pool/disk1 ext4 defaults 0 0
mount -a
lsblk # Check if the disk is mounted

- Master (assuming 3 nodes, 1 disk per node, change appropriately if you have more disks per node)
sudo gluster volume create pool-name disperse 3 redundancy 1 \
  XX.XX.XX.XX:/pool/disk1 \
  YY.YY.YY.YY:/pool/disk1 \
  ZZ.ZZ.ZZ.ZZ:/pool/disk1 \
  force

sudo gluster volume start pool-name
sudo gluster volume info
```

## Mounting the volume on all nodes
```bash
- Nodes that you want to mount the volume on
sudo apt install glusterfs-client -y
sudo mkdir -p /mnt/pool-name
sudo nano /etc/fstab

localhost:/pool-name /mnt/pool-name glusterfs defaults,_netdev,noauto,x-systemd.automount,backup-volfile-servers=<NODE_2_IP>:<NODE_3_IP> 0 0 # Use IPs of other nodes in the cluster

sudo mount -a
df -h

sudo chown -R user:group /mnt/pool-name
sudo chmod -R 775 /mnt/pool-name
```

## SMB
```bash
- Master (or any node that you want to run SMB on)
sudo apt install samba -y

sudo nano /etc/samba/smb.conf
[pool-name]
    comment = GlusterFS Pool Name
    path = /mnt/pool-name
    browseable = yes
    read only = no
    guest ok = no
    valid users = user

sudo smbpasswd -a user

sudo systemctl restart smbd
sudo systemctl enable smbd
```

## NFS
```bash
- Master (or any node that you want to run NFS on)
sudo apt install nfs-kernel-server -y

sudo nano /etc/exports
/mnt/pool-name XX.XX.XX.0/24(rw,sync,no_subtree_check,no_root_squash,fsid=1)

sudo exportfs -ra

sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server
```
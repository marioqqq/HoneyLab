Before using Ansible, update your system and install following packages on host:
```bash
sudo apt install ansible sshpass -y
```

And other machines:
```bash
sudo apt install ansible -y
```

For desktop machine, run:
```bash
sudo apt install ssh -y
sudo ufw allow 22
```

Before first use, create config file and change `host_key_checking` to `False`:
```bash
ansible-config init --disabled > ansible.cfg
```

Then edit [hosts](/Ansible/inventory/hosts) file.

Create and copy SSH key:
```bash
ansible-playbook ./Ansible/playbooks/generate-ssh-key.yaml -i ./Ansible/inventory/hosts --ask-pass
ansible-playbook ./Ansible/playbooks/copy-ssh-key.yaml -i ./Ansible/inventory/hosts --ask-pass
```

If you need to copy SSH key to new machine:
```bash
ansible-playbook ./Ansible/playbooks/copy-ssh-key.yaml -i ./Ansible/inventory/hosts --ask-pass --limit "SRV-xyz"
```

Test connection to all machines:
```bash
ansible -i ./Ansible/inventory/hosts SRV_Collection -m ping --ask-pass
```

To run playbook, use:
```bash
ansible-playbook ./Ansible/playbooks/update.yaml -i ./Ansible/inventory/hosts --ask-become-pass
ansible-playbook ./Ansible/playbooks/SRV-Management.yaml -i ./Ansible/inventory/hosts --ask-become-pass
ansible-playbook ./Ansible/playbooks/SRV-Arr.yaml -i ./Ansible/inventory/hosts --ask-become-pass
ansible-playbook ./Ansible/playbooks/SRV-Media.yaml -i ./Ansible/inventory/hosts --ask-become-pass
ansible-playbook ./Ansible/playbooks/SRV-Personal.yaml -i ./Ansible/inventory/hosts --ask-become-pass
ansible-playbook ./Ansible/playbooks/SRV-VPN.yaml -i ./Ansible/inventory/hosts --ask-become-pass
ansible-playbook ./Ansible/playbooks/SRV-Backup.yaml -i ./Ansible/inventory/hosts --ask-become-pass
ansible-playbook ./Ansible/playbooks/PC-Desktop.yaml -i ./Ansible/inventory/hosts --ask-become-pass
```
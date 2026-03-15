# TrueNAS Scripts

> **Disclaimer**  
> These scripts were created with assistance from AI and may contain bugs or unexpected behavior. Test them before production use and use at your own risk.

---

# [Main.sh](/TrueNAS/Main.sh)

Runs **NVMe SMART self-tests** on the main TrueNAS machine.

### What it does

- Detects all NVMe drives
- Starts NVMe SMART self-tests
- Runs only if the last test was **≥ 30 days ago**
- Sends alerts to the TrueNAS alert system
- Writes logs to `/var/log`
- Does **not** shut down the system
- Does **not** run scrubs (handled by TrueNAS)

---

# [Backup.sh](/TrueNAS/Backup.sh)

Automates backup and maintenance on the **secondary TrueNAS machine**.

### What it does

- Checks connectivity to the main TrueNAS server
- Runs all enabled **replication tasks**
- Runs SMART tests on all drives (NVMe / SATA / SAS)
- Runs a **ZFS scrub when needed**
- Waits for scrub completion (up to 1 hour)
- Sends alerts through the TrueNAS alert system
- Logs execution results
- **Shuts down the backup machine when finished**

---

## Setup
### 1. Copy script
```bash
cp script.sh /root/scripts/script.sh
chmod 700 /root/scripts/script.sh
```

### Configure variables (only for Backup.sh)
```bash
MAIN_TRUENAS_IP="your_ip"
BACKUP_POOL="your_pool"
MIN_DAYS_BETWEEN_SCRUBS=35
MIN_DAYS_BETWEEN_SMART=30
```

### 2. Schedule with cron
Depends on your needs.

### 3. Check logs and alerts
`/var/log/truenas_backup_TIMESTAMP.log`
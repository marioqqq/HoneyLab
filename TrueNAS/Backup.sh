#!/bin/bash

################################################################################
# TrueNAS Backup Automation Script - BACKUP MACHINE
#
# Purpose: Automated backup for backup TrueNAS machine
# - Pulls replication from main TrueNAS
# - Runs SMART tests on all drives (auto-detects NVMe/SATA/SAS)
# - Runs scrub if needed (>30 days since last)
# - Sends TrueNAS alerts for each step
# - Always shuts down at the end (even on failures)
#
# Schedule: Run at 00:00 daily via cron
# Machine: Backup TrueNAS (powered on at 23:50 via WoL)
#
# Installation:
# 1. Copy to /root/scripts/Backup.sh
# 2. chmod 700 /root/scripts/Backup.sh
# 3. Edit configuration below (MAIN_TRUENAS_IP and BACKUP_POOL)
# 4. Add to cron: 0 0 * * * /root/scripts/Backup.sh
################################################################################

set -uo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - UPDATE THESE
MAIN_TRUENAS_IP="xx.xx.xx.xx"     # IP of your main TrueNAS
BACKUP_POOL="Backup"              # Name of your backup pool
MIN_DAYS_BETWEEN_SCRUBS=35        # Minimum days between scrubs
MIN_DAYS_BETWEEN_SMART=30         # Minimum days between SMART tests

# System variables - DO NOT CHANGE
LOG_FILE="/var/log/truenas_backup_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# Logging and Alert Functions
################################################################################

log() {
    local message="$1"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${timestamp} ${message}" | tee -a "$LOG_FILE"
}

send_alert() {
    local level="$1"
    local title="$2"
    local message="$3"

    log "[$level] $title: $message"

    local alert_text="${title}: ${message}"
    midclt call alert.oneshot_create "$level" "$alert_text" 2>/dev/null || true
}

################################################################################
# Main Functions
################################################################################

check_connectivity() {
    log "${BLUE}=== Connectivity Check ===${NC}"

    if ping -c 3 -W 5 "$MAIN_TRUENAS_IP" &>/dev/null; then
        log "${GREEN}✓${NC} Main TrueNAS is reachable"
        send_alert "INFO" "Connectivity Check" "Main TrueNAS ($MAIN_TRUENAS_IP) is reachable"
        return 0
    else
        log "${RED}✗${NC} Cannot reach main TrueNAS"
        send_alert "CRITICAL" "Connectivity Check Failed" "Cannot reach main TrueNAS at $MAIN_TRUENAS_IP"
        return 1
    fi
}

run_replication_tasks() {
    log "${BLUE}=== Replication Tasks ===${NC}"

    local success=0
    local failed=0
    local failed_names=""

    local tasks=$(midclt call replication.query 2>/dev/null | jq -r '.[] | select(.enabled == true) | "\(.id)|\(.name)"' 2>/dev/null)

    if [ -z "$tasks" ]; then
        log "${YELLOW}⚠${NC} No enabled replication tasks found"
        send_alert "WARNING" "Replication Tasks" "No enabled replication tasks found"
        return 1
    fi

    local task_count=$(echo "$tasks" | wc -l)
    log "Found ${YELLOW}$task_count${NC} enabled replication task(s)"

    while IFS='|' read -r task_id task_name; do
        [ -z "$task_id" ] && continue

        log "Starting: ${YELLOW}$task_name${NC} (ID: $task_id)"

        # Trigger replication
        if ! midclt call replication.run "$task_id" >/dev/null 2>&1; then
            log "  ${RED}✗${NC} Failed to start $task_name"
            ((failed++))
            failed_names="${failed_names}${task_name} (start failed), "
            continue
        fi

        log "  Triggered replication for $task_name"

        # Monitor replication - check job STATE not just existence
        local max_wait=7200
        local waited=0
        local last_check=0

        while [ $waited -lt $max_wait ]; do
            sleep 2
            ((waited+=2))
            ((last_check+=2))

            # Get job state for this replication task
            local job_state=$(midclt call core.get_jobs 2>/dev/null | jq -r "[.[] | select(.method == \"replication.run\" and .arguments[0] == $task_id)] | .[0].state // \"NOTFOUND\"" 2>/dev/null)

            case "$job_state" in
                "RUNNING"|"WAITING")
                    # Job is actively running
                    if [ $last_check -ge 30 ]; then
                        log "  ${BLUE}...${NC} $task_name replicating (${waited}s elapsed)"
                        last_check=0
                    fi
                    ;;
                "SUCCESS")
                    # Job completed successfully
                    log "  ${GREEN}✓${NC} $task_name completed successfully (${waited}s)"
                    ((success++))
                    break
                    ;;
                "FAILED"|"ABORTED")
                    # Job failed
                    log "  ${RED}✗${NC} $task_name failed"
                    ((failed++))
                    failed_names="${failed_names}${task_name}, "
                    break
                    ;;
                "NOTFOUND")
                    # No job found - completed so fast we didn't see it
                    if [ $waited -ge 8 ]; then
                        log "  ${GREEN}✓${NC} $task_name completed (no changes to sync)"
                        ((success++))
                        break
                    fi
                    ;;
                *)
                    # Unknown state, keep waiting
                    ;;
            esac
        done

        # Check if we timed out
        if [ $waited -ge $max_wait ]; then
            log "  ${RED}✗${NC} $task_name timed out after ${max_wait}s"
            ((failed++))
            failed_names="${failed_names}${task_name} (timeout), "
        fi

    done <<< "$tasks"

    log "Replication Summary: ${GREEN}$success successful${NC}, ${RED}$failed failed${NC}"

    if [ $failed -eq 0 ]; then
        send_alert "INFO" "Replication Complete" "All $success replication tasks completed successfully"
        return 0
    else
        failed_names="${failed_names%, }"
        send_alert "CRITICAL" "Replication Failed" "$failed task(s) failed: $failed_names"
        return 1
    fi
}

run_smart_tests() {
    log "${BLUE}=== SMART Tests ===${NC}"

    # Check last SMART test time
    local last_test_file="/var/log/.last_smart_test"
    local current_time=$(date +%s)
    local should_run=false

    if [ -f "$last_test_file" ]; then
        local last_test_time=$(cat "$last_test_file")
        local days_since=$(( ($current_time - $last_test_time) / 86400 ))
        log "Last SMART test: ${YELLOW}$days_since days ago${NC}"

        if [ $days_since -ge $MIN_DAYS_BETWEEN_SMART ]; then
            should_run=true
        else
            log "${GREEN}✓${NC} SMART tests not needed (minimum $MIN_DAYS_BETWEEN_SMART days between tests)"
            send_alert "INFO" "SMART Tests" "SMART tests not needed (last run: $days_since days ago)"
            return 0
        fi
    else
        log "No previous SMART test record found"
        should_run=true
    fi

    if [ "$should_run" = false ]; then
        return 0
    fi

    local tests_started=0
    local tests_failed=0

    # Test NVMe drives
    for dev in /dev/nvme*n1; do
        [ -e "$dev" ] || continue
        disk=$(basename "$dev")

        log "Running NVMe self-test on ${YELLOW}$disk${NC}"
        if nvme device-self-test /dev/$disk -s 1 >/dev/null 2>&1; then
            log "  ${GREEN}✓${NC} NVMe self-test started on $disk"
            ((tests_started++))
        else
            log "  ${RED}⚠${NC} Failed to start NVMe self-test on $disk"
            ((tests_failed++))
        fi
    done

    # Test SATA/SAS drives
    for dev in /dev/ada* /dev/sd[a-z] /dev/da*; do
        [ -e "$dev" ] || continue
        [[ "$dev" =~ (p[0-9]+|[0-9]+)$ ]] && continue
        disk=$(basename "$dev")

        log "Running SMART test on ${YELLOW}$disk${NC}"
        if smartctl -t short "/dev/$disk" >/dev/null 2>&1; then
            log "  ${GREEN}✓${NC} SMART test started on $disk"
            ((tests_started++))
        else
            log "  ${RED}⚠${NC} Failed to start SMART test on $disk"
            ((tests_failed++))
        fi
    done

    if [ $tests_started -gt 0 ]; then
        # Record test time
        echo "$current_time" > "$last_test_file"
        log "Started ${GREEN}$tests_started${NC} SMART tests (${RED}$tests_failed${NC} failed)"
        send_alert "INFO" "SMART Tests" "Started $tests_started SMART tests on all drives"
        return 0
    else
        log "${RED}No SMART tests started${NC}"
        send_alert "WARNING" "SMART Tests" "No drives found or all tests failed"
        return 1
    fi
}

run_scrub_tasks() {
    log "${BLUE}=== Scrub Tasks ===${NC}"

    if ! zpool list "$BACKUP_POOL" &>/dev/null; then
        log "${RED}✗${NC} Pool $BACKUP_POOL not found"
        send_alert "CRITICAL" "Scrub Failed" "Pool $BACKUP_POOL not found"
        return 1
    fi

    local scrub_info=$(zpool status "$BACKUP_POOL" | grep -A 2 "scan:")
    local scrub_started=false

    # Check if scrub is currently running
    if echo "$scrub_info" | grep -q "scrub in progress"; then
        scrub_started=true
        log "${BLUE}Scrub already in progress${NC}"
        local scrub_time=$(echo "$scrub_info" | grep "scrub in progress" | sed -n 's/.*since \(.*\)$/\1/p')
        log "Started: $scrub_time"
        send_alert "INFO" "Scrub Detected" "Scrub already running on $BACKUP_POOL (started: $scrub_time). Waiting for completion..."
    else
        # Check when last scrub completed
        if echo "$scrub_info" | grep -q "scrub repaired"; then
            local last_scrub_date=$(echo "$scrub_info" | grep "scrub repaired" | sed -n 's/.*on \(.*\)$/\1/p')
            local last_scrub_epoch=$(date -d "$last_scrub_date" +%s 2>/dev/null || echo 0)
            local current_epoch=$(date +%s)
            local days_since=$((($current_epoch - $last_scrub_epoch) / 86400))

            log "Last scrub: ${YELLOW}$days_since days ago${NC} ($last_scrub_date)"

            if [ $days_since -lt $MIN_DAYS_BETWEEN_SCRUBS ]; then
                log "${GREEN}✓${NC} Scrub not needed (minimum $MIN_DAYS_BETWEEN_SCRUBS days between scrubs)"
                send_alert "INFO" "Scrub Check" "Scrub not needed for $BACKUP_POOL (last scrub: $days_since days ago)"
                return 0
            fi
        else
            log "${YELLOW}No previous scrub found${NC}"
        fi

        # Start new scrub
        log "Starting scrub on ${YELLOW}$BACKUP_POOL${NC}..."
        if zpool scrub "$BACKUP_POOL" >/dev/null 2>&1; then
            log "${GREEN}✓${NC} Scrub started on $BACKUP_POOL"
            send_alert "INFO" "Scrub Started" "Scrub started on pool $BACKUP_POOL. Waiting for completion..."
            scrub_started=true
        else
            log "${RED}✗${NC} Failed to start scrub on $BACKUP_POOL"
            send_alert "WARNING" "Scrub Failed" "Failed to start scrub on $BACKUP_POOL"
            return 1
        fi
    fi

    # Wait for scrub to complete (max 1 hour)
    if [ "$scrub_started" = true ]; then
        local max_wait=3600  # 1 hour
        local waited=0
        local last_log=0

        log "Waiting for scrub to complete (max 1 hour)..."

        while [ $waited -lt $max_wait ]; do
            sleep 10
            ((waited+=10))
            ((last_log+=10))

            # Check scrub status
            scrub_info=$(zpool status "$BACKUP_POOL" | grep -A 2 "scan:")

            if echo "$scrub_info" | grep -q "scrub repaired"; then
                # Scrub completed
                local errors=$(echo "$scrub_info" | grep "scrub repaired" | sed -n 's/.*scrub repaired \([^ ]*\).*/\1/p')
                log "${GREEN}✓${NC} Scrub completed successfully (waited ${waited}s)"

                if [ "$errors" != "0B" ] && [ -n "$errors" ]; then
                    log "${YELLOW}⚠${NC} Scrub found and repaired: $errors"
                    send_alert "WARNING" "Scrub Complete" "Scrub completed on $BACKUP_POOL. Repaired: $errors"
                else
                    send_alert "INFO" "Scrub Complete" "Scrub completed successfully on $BACKUP_POOL. No errors found."
                fi
                return 0
            elif echo "$scrub_info" | grep -q "scrub in progress"; then
                # Still running
                if [ $last_log -ge 60 ]; then
                    # Log progress every minute
                    local progress=$(echo "$scrub_info" | grep -o "[0-9.]*% done" | head -1)
                    if [ -n "$progress" ]; then
                        log "  ${BLUE}...${NC} Scrub in progress: $progress (${waited}s elapsed)"
                    else
                        log "  ${BLUE}...${NC} Scrub in progress (${waited}s elapsed)"
                    fi
                    last_log=0
                fi
            else
                # Unknown state
                log "${YELLOW}⚠${NC} Scrub state unclear after ${waited}s"
                return 0
            fi
        done

        # Timeout
        log "${YELLOW}⚠${NC} Scrub still running after 1 hour - will continue in background"
        send_alert "WARNING" "Scrub Timeout" "Scrub on $BACKUP_POOL still running after 1 hour. Will continue in background after shutdown."
        return 0
    fi

    return 0
}

safe_shutdown() {
    log "${BLUE}=== Safe Shutdown ===${NC}"

    log "Syncing filesystems..."
    sync

    send_alert "INFO" "Backup Complete" "All backup tasks completed. System will shutdown."

    log "${YELLOW}Scheduling shutdown...${NC}"
    shutdown &

    log "${GREEN}✓${NC} Shutdown scheduled. Script complete."
}

################################################################################
# Main Execution
################################################################################

main() {
    log ""
    log "${BLUE}==========================================${NC}"
    log "${BLUE}TrueNAS Backup Script Started${NC}"
    log "${BLUE}==========================================${NC}"

    send_alert "INFO" "Backup Started" "Automated backup process has begun"

    local overall_status=0
    local failed_steps=""

    if ! check_connectivity; then
        overall_status=1
        failed_steps="${failed_steps}Connectivity, "
        log "${YELLOW}⚠${NC} Connectivity check failed - continuing anyway"
    fi

    if ! run_replication_tasks; then
        overall_status=1
        failed_steps="${failed_steps}Replication, "
        log "${YELLOW}⚠${NC} Replication failed - continuing with maintenance tasks"
    fi

    if ! run_smart_tests; then
        overall_status=1
        failed_steps="${failed_steps}SMART Tests, "
        log "${YELLOW}⚠${NC} SMART tests failed - continuing anyway"
    fi

    if ! run_scrub_tasks; then
        overall_status=1
        failed_steps="${failed_steps}Scrub, "
        log "${YELLOW}⚠${NC} Scrub failed - continuing to shutdown"
    fi

    if [ $overall_status -eq 0 ]; then
        send_alert "INFO" "Backup Process Complete" "All tasks completed successfully. System will shutdown."
    else
        failed_steps="${failed_steps%, }"
        send_alert "WARNING" "Backup Completed With Failures" "Failed steps: ${failed_steps}. Check logs at $LOG_FILE. System will shutdown."
    fi

    safe_shutdown

    log "${BLUE}==========================================${NC}"
    if [ $overall_status -eq 0 ]; then
        log "${GREEN}Script Finished - Status: SUCCESS${NC}"
    else
        log "${YELLOW}Script Finished - Status: PARTIAL FAILURE${NC}"
    fi
    log "${BLUE}==========================================${NC}"
    log ""

    exit $overall_status
}

main "$@"
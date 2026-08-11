#!/bin/bash

################################################################################
# TrueNAS Backup Script - BACKUP MACHINE
#
# Purpose: Automated backup for backup TrueNAS machine
# - Pulls replication from Main TrueNAS
# - Runs SMART tests on all drives (auto-detects NVMe/SATA/SAS)
# - Waits for SMART tests to finish and checks results
# - Runs scrub if needed (>35 days since last)
# - Sends one Gotify notification with final status
# - Always shuts down at the end (even on failures)
#
# Schedule: Run at 00:00 daily via cron
# Machine: Backup TrueNAS (powered on at 23:50 via WoL)
#
# Installation:
# 1. Copy to /root/scripts/Backup.sh
# 2. chmod 700 /root/scripts/Backup.sh
# 3. Edit configuration below
# 4. Add to cron: 0 0 * * * /root/scripts/Backup.sh
################################################################################

set -uo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - UPDATE THESE
MAIN_TRUENAS_IP="XX.XX.XX.XX"  # IP of the main TrueNAS machine
BACKUP_POOL="Backup"

GOTIFY_URL="https://gotify.example.com"
GOTIFY_TOKEN="YOUR_APP_TOKEN"

MIN_DAYS_BETWEEN_SCRUBS=35
MIN_DAYS_BETWEEN_SMART=30

SMART_POLL_INTERVAL=10
SMART_TIMEOUT=1800

# System variables - DO NOT CHANGE
LOG_FILE="/var/log/Backup_$(date +%Y%m%d_%H%M%S).log"

################################################################################
# Logging and Notification Functions
################################################################################

log() {
    local message="$1"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo -e "${timestamp} ${message}" | tee -a "$LOG_FILE"
}

send_gotify() {
    local priority="$1"
    local title="$2"
    local message="$3"

    log "[GOTIFY] $title: $message"

    curl -fsS \
        --connect-timeout 5 \
        --max-time 10 \
        -X POST \
        "${GOTIFY_URL}/message?token=${GOTIFY_TOKEN}" \
        -F "title=${title}" \
        -F "message=${message}" \
        -F "priority=${priority}" \
        >> "$LOG_FILE" 2>&1 \
        || log "${RED}Failed to send Gotify notification${NC}"
}

################################################################################
# Connectivity
################################################################################

check_connectivity() {
    log "${BLUE}=== Connectivity Check ===${NC}"

    if ping -c 3 -W 5 "$MAIN_TRUENAS_IP" &>/dev/null; then
        log "${GREEN}✓${NC} Main TrueNAS is reachable"
        CONNECTIVITY_STATUS="OK"
        return 0
    else
        log "${RED}✗${NC} Cannot reach main TrueNAS"
        CONNECTIVITY_STATUS="FAILED"
        return 1
    fi
}

################################################################################
# Replication
################################################################################

run_replication_tasks() {
    log "${BLUE}=== Replication Tasks ===${NC}"

    local success=0
    local failed=0
    local failed_names=""

    local tasks
    tasks=$(midclt call replication.query 2>/dev/null |
        jq -r '.[] | select(.enabled == true) | "\(.id)|\(.name)"' 2>/dev/null)

    if [ -z "$tasks" ]; then
        log "${YELLOW}⚠${NC} No enabled replication tasks found"

        REPLICATION_STATUS="FAILED"
        REPLICATION_MESSAGE="No enabled replication tasks found"

        return 1
    fi

    local task_count
    task_count=$(echo "$tasks" | wc -l)

    log "Found ${YELLOW}$task_count${NC} enabled replication task(s)"

    while IFS='|' read -r task_id task_name; do
        [ -z "$task_id" ] && continue

        log "Starting: ${YELLOW}$task_name${NC} (ID: $task_id)"

        if ! midclt call replication.run "$task_id" >/dev/null 2>&1; then
            log "  ${RED}✗${NC} Failed to start $task_name"

            ((failed++))
            failed_names="${failed_names}${task_name} (start failed), "

            continue
        fi

        log "  Triggered replication for $task_name"

        local max_wait=7200
        local waited=0
        local last_check=0

        while [ $waited -lt $max_wait ]; do
            sleep 2

            ((waited+=2))
            ((last_check+=2))

            local job_state
            job_state=$(
                midclt call core.get_jobs 2>/dev/null |
                jq -r "[.[] |
                    select(
                        .method == \"replication.run\" and
                        .arguments[0] == $task_id
                    )
                ] | .[0].state // \"NOTFOUND\"" 2>/dev/null
            )

            case "$job_state" in
                "RUNNING"|"WAITING")
                    if [ $last_check -ge 30 ]; then
                        log "  ${BLUE}...${NC} $task_name replicating (${waited}s elapsed)"
                        last_check=0
                    fi
                    ;;

                "SUCCESS")
                    log "  ${GREEN}✓${NC} $task_name completed successfully (${waited}s)"
                    ((success++))
                    break
                    ;;

                "FAILED"|"ABORTED")
                    log "  ${RED}✗${NC} $task_name failed"

                    ((failed++))
                    failed_names="${failed_names}${task_name}, "

                    break
                    ;;

                "NOTFOUND")
                    if [ $waited -ge 8 ]; then
                        log "  ${GREEN}✓${NC} $task_name completed (no changes to sync)"
                        ((success++))
                        break
                    fi
                    ;;
            esac
        done

        if [ $waited -ge $max_wait ]; then
            log "  ${RED}✗${NC} $task_name timed out after ${max_wait}s"

            ((failed++))
            failed_names="${failed_names}${task_name} (timeout), "
        fi

    done <<< "$tasks"

    log "Replication Summary: ${GREEN}$success successful${NC}, ${RED}$failed failed${NC}"

    if [ $failed -eq 0 ]; then
        REPLICATION_STATUS="OK"
        REPLICATION_MESSAGE="$success task(s) successful"
        return 0
    else
        failed_names="${failed_names%, }"

        REPLICATION_STATUS="FAILED"
        REPLICATION_MESSAGE="$failed failed: $failed_names"

        return 1
    fi
}

################################################################################
# SMART Tests
################################################################################

run_smart_tests() {
    log "${BLUE}=== SMART Tests ===${NC}"

    local last_test_file="/var/log/.last_smart_test"
    local current_time
    current_time=$(date +%s)

    SMART_STATUS="SKIPPED"
    SMART_MESSAGE="Not required"

    ########################################################################
    # Check last SMART run
    ########################################################################

    if [ -f "$last_test_file" ]; then
        local last_test_time
        local days_since

        last_test_time=$(cat "$last_test_file")
        days_since=$(( (current_time - last_test_time) / 86400 ))

        log "Last SMART test: ${YELLOW}$days_since days ago${NC}"

        if [ "$days_since" -lt "$MIN_DAYS_BETWEEN_SMART" ]; then
            log "${GREEN}✓${NC} SMART tests not needed (minimum $MIN_DAYS_BETWEEN_SMART days between tests)"

            SMART_STATUS="SKIPPED"
            SMART_MESSAGE="Not due ($days_since days since last test)"

            return 0
        fi
    else
        log "No previous SMART test record found"
    fi

    ########################################################################
    # Start tests
    ########################################################################

    local tests_started=0
    local tests_start_failed=0

    local nvme_devices=()
    local smart_devices=()

    # NVMe
    for dev in /dev/nvme*n1; do
        [ -e "$dev" ] || continue

        local disk
        disk=$(basename "$dev")

        log "Starting NVMe self-test on ${YELLOW}$disk${NC}"

        if nvme device-self-test "$dev" -s 1 >/dev/null 2>&1; then
            log "  ${GREEN}✓${NC} NVMe self-test started on $disk"

            nvme_devices+=("$dev")
            ((tests_started++))
        else
            log "  ${RED}⚠${NC} Failed to start NVMe self-test on $disk"
            ((tests_start_failed++))
        fi
    done

    # SATA/SAS
    for dev in /dev/ada* /dev/sd[a-z] /dev/da*; do
        [ -e "$dev" ] || continue
        [[ "$dev" =~ (p[0-9]+|[0-9]+)$ ]] && continue

        local disk
        disk=$(basename "$dev")

        log "Starting SMART self-test on ${YELLOW}$disk${NC}"

        if smartctl -t short "$dev" >/dev/null 2>&1; then
            log "  ${GREEN}✓${NC} SMART self-test started on $disk"

            smart_devices+=("$dev")
            ((tests_started++))
        else
            log "  ${RED}⚠${NC} Failed to start SMART self-test on $disk"
            ((tests_start_failed++))
        fi
    done

    if [ "$tests_started" -eq 0 ]; then
        log "${RED}No SMART tests could be started${NC}"

        SMART_STATUS="FAILED"
        SMART_MESSAGE="No SMART tests could be started"

        return 1
    fi

    log "Started ${GREEN}$tests_started${NC} SMART tests"
    log "${BLUE}Waiting for SMART tests to finish...${NC}"

    ########################################################################
    # Wait for tests
    ########################################################################

    local wait_start
    wait_start=$(date +%s)

    while true; do
        local tests_running=0

        # NVMe status
        for dev in "${nvme_devices[@]}"; do
            local operation

            operation=$(
                nvme self-test-log "$dev" 2>/dev/null |
                awk -F: '/Current operation/ {
                    gsub(/[[:space:]]/, "", $2)
                    print $2
                    exit
                }'
            )

            if [ -z "$operation" ]; then
                log "${YELLOW}⚠${NC} Unable to read NVMe test status for $(basename "$dev")"
                ((tests_running++))
                continue
            fi

            if (( operation != 0 )); then
                ((tests_running++))
            fi
        done

        # SATA/SAS status
        for dev in "${smart_devices[@]}"; do
            if smartctl -c "$dev" 2>/dev/null |
                grep -qi "Self-test routine in progress"; then

                ((tests_running++))
            fi
        done

        if [ "$tests_running" -eq 0 ]; then
            break
        fi

        local now
        now=$(date +%s)

        if [ $((now - wait_start)) -ge "$SMART_TIMEOUT" ]; then
            log "${RED}⚠ SMART test timeout reached${NC}"

            SMART_STATUS="FAILED"
            SMART_MESSAGE="SMART tests did not finish within $((SMART_TIMEOUT / 60)) minutes"

            return 1
        fi

        log "SMART tests still running: ${YELLOW}$tests_running${NC}"

        sleep "$SMART_POLL_INTERVAL"
    done

    ########################################################################
    # Check results
    ########################################################################

    log "${BLUE}=== SMART Test Results ===${NC}"

    local tests_passed=0
    local tests_result_failed=0

    # NVMe results
    for dev in "${nvme_devices[@]}"; do
        local disk
        local result

        disk=$(basename "$dev")

        result=$(
            nvme self-test-log "$dev" 2>/dev/null |
            awk -F: '/Operation Result/ {
                gsub(/[[:space:]]/, "", $2)
                print $2
                exit
            }'
        )

        if [ "$result" = "0" ] || [ "$result" = "0x0" ]; then
            log "  ${GREEN}✓${NC} $disk passed"
            ((tests_passed++))
        else
            log "  ${RED}⚠${NC} $disk failed (result: ${result:-unknown})"
            ((tests_result_failed++))
        fi
    done

    # SATA/SAS results
    for dev in "${smart_devices[@]}"; do
        local disk
        local result

        disk=$(basename "$dev")

        result=$(
            smartctl -l selftest "$dev" 2>/dev/null |
            awk '/^# *1/ {
                line=$0
                sub(/^# *1 +/, "", line)
                print line
                exit
            }'
        )

        if echo "$result" | grep -qi "Completed without error"; then
            log "  ${GREEN}✓${NC} $disk passed"
            ((tests_passed++))
        else
            log "  ${RED}⚠${NC} $disk failed (${result:-unknown result})"
            ((tests_result_failed++))
        fi
    done

    ########################################################################
    # Final SMART status
    ########################################################################

    local total_failed
    total_failed=$((tests_start_failed + tests_result_failed))

    if [ "$total_failed" -eq 0 ]; then
        echo "$current_time" > "$last_test_file"

        SMART_STATUS="OK"
        SMART_MESSAGE="$tests_passed drive(s) passed"

        log "${GREEN}✓ All $tests_passed SMART tests passed${NC}"

        return 0
    else
        SMART_STATUS="FAILED"
        SMART_MESSAGE="$tests_passed passed, $total_failed failed"

        log "${RED}⚠ SMART tests finished with failures${NC}"

        return 1
    fi
}

################################################################################
# Scrub
################################################################################

run_scrub_tasks() {
    log "${BLUE}=== Scrub Tasks ===${NC}"

    SCRUB_STATUS="SKIPPED"
    SCRUB_MESSAGE="Not required"

    if ! zpool list "$BACKUP_POOL" &>/dev/null; then
        log "${RED}✗${NC} Pool $BACKUP_POOL not found"

        SCRUB_STATUS="FAILED"
        SCRUB_MESSAGE="Pool $BACKUP_POOL not found"

        return 1
    fi

    local scrub_info
    scrub_info=$(zpool status "$BACKUP_POOL" | grep -A 2 "scan:")

    local scrub_started=false

    ########################################################################
    # Existing scrub
    ########################################################################

    if echo "$scrub_info" | grep -q "scrub in progress"; then
        scrub_started=true

        log "${BLUE}Scrub already in progress${NC}"

        local scrub_time
        scrub_time=$(echo "$scrub_info" |
            grep "scrub in progress" |
            sed -n 's/.*since \(.*\)$/\1/p')

        log "Started: $scrub_time"

    else
        ####################################################################
        # Check last scrub
        ####################################################################

        if echo "$scrub_info" | grep -q "scrub repaired"; then
            local last_scrub_date
            local last_scrub_epoch
            local current_epoch
            local days_since

            last_scrub_date=$(
                echo "$scrub_info" |
                grep "scrub repaired" |
                sed -n 's/.*on \(.*\)$/\1/p'
            )

            last_scrub_epoch=$(
                date -d "$last_scrub_date" +%s 2>/dev/null || echo 0
            )

            current_epoch=$(date +%s)
            days_since=$(( (current_epoch - last_scrub_epoch) / 86400 ))

            log "Last scrub: ${YELLOW}$days_since days ago${NC} ($last_scrub_date)"

            if [ "$days_since" -lt "$MIN_DAYS_BETWEEN_SCRUBS" ]; then
                log "${GREEN}✓${NC} Scrub not needed"

                SCRUB_STATUS="SKIPPED"
                SCRUB_MESSAGE="Not due ($days_since days since last scrub)"

                return 0
            fi
        else
            log "${YELLOW}No previous scrub found${NC}"
        fi

        ####################################################################
        # Start scrub
        ####################################################################

        log "Starting scrub on ${YELLOW}$BACKUP_POOL${NC}..."

        if zpool scrub "$BACKUP_POOL" >/dev/null 2>&1; then
            log "${GREEN}✓${NC} Scrub started on $BACKUP_POOL"
            scrub_started=true
        else
            log "${RED}✗${NC} Failed to start scrub on $BACKUP_POOL"

            SCRUB_STATUS="FAILED"
            SCRUB_MESSAGE="Failed to start scrub"

            return 1
        fi
    fi

    ########################################################################
    # Wait for scrub
    ########################################################################

    if [ "$scrub_started" = true ]; then
        local max_wait=3600
        local waited=0
        local last_log=0

        log "Waiting for scrub to complete (max 1 hour)..."

        while [ $waited -lt $max_wait ]; do
            sleep 10

            ((waited+=10))
            ((last_log+=10))

            scrub_info=$(zpool status "$BACKUP_POOL" | grep -A 2 "scan:")

            if echo "$scrub_info" | grep -q "scrub repaired"; then
                local errors

                errors=$(
                    echo "$scrub_info" |
                    grep "scrub repaired" |
                    sed -n 's/.*scrub repaired \([^ ]*\).*/\1/p'
                )

                log "${GREEN}✓${NC} Scrub completed (${waited}s)"

                if [ "$errors" != "0B" ] && [ -n "$errors" ]; then
                    log "${YELLOW}⚠${NC} Scrub repaired: $errors"

                    SCRUB_STATUS="WARNING"
                    SCRUB_MESSAGE="Completed, repaired $errors"
                else
                    SCRUB_STATUS="OK"
                    SCRUB_MESSAGE="Completed, no errors"
                fi

                return 0

            elif echo "$scrub_info" | grep -q "scrub in progress"; then

                if [ $last_log -ge 60 ]; then
                    local progress

                    progress=$(
                        echo "$scrub_info" |
                        grep -o "[0-9.]*% done" |
                        head -1
                    )

                    if [ -n "$progress" ]; then
                        log "  ${BLUE}...${NC} Scrub: $progress (${waited}s elapsed)"
                    else
                        log "  ${BLUE}...${NC} Scrub in progress (${waited}s elapsed)"
                    fi

                    last_log=0
                fi

            else
                log "${YELLOW}⚠${NC} Scrub state unclear"

                SCRUB_STATUS="WARNING"
                SCRUB_MESSAGE="Scrub state unclear"

                return 0
            fi
        done

        log "${YELLOW}⚠${NC} Scrub still running after 1 hour"

        SCRUB_STATUS="WARNING"
        SCRUB_MESSAGE="Still running after 1 hour"

        return 0
    fi

    return 0
}

################################################################################
# Shutdown
################################################################################

safe_shutdown() {
    log "${BLUE}=== Safe Shutdown ===${NC}"

    log "Syncing filesystems..."
    sync

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

    local overall_status=0
    local failed_steps=""

    CONNECTIVITY_STATUS="UNKNOWN"
    REPLICATION_STATUS="UNKNOWN"
    REPLICATION_MESSAGE=""
    SMART_STATUS="UNKNOWN"
    SMART_MESSAGE=""
    SCRUB_STATUS="UNKNOWN"
    SCRUB_MESSAGE=""

    ########################################################################
    # Connectivity
    ########################################################################

    if ! check_connectivity; then
        overall_status=1
        failed_steps="${failed_steps}Connectivity, "

        log "${YELLOW}⚠${NC} Connectivity check failed - continuing anyway"
    fi

    ########################################################################
    # Replication
    ########################################################################

    if ! run_replication_tasks; then
        overall_status=1
        failed_steps="${failed_steps}Replication, "

        log "${YELLOW}⚠${NC} Replication failed - continuing with maintenance tasks"
    fi

    ########################################################################
    # SMART
    ########################################################################

    if ! run_smart_tests; then
        overall_status=1
        failed_steps="${failed_steps}SMART, "

        log "${YELLOW}⚠${NC} SMART tests failed - continuing anyway"
    fi

    ########################################################################
    # Scrub
    ########################################################################

    if ! run_scrub_tasks; then
        overall_status=1
        failed_steps="${failed_steps}Scrub, "

        log "${YELLOW}⚠${NC} Scrub failed - continuing to shutdown"
    fi

    ########################################################################
    # One final Gotify notification
    ########################################################################

    local notification

    notification="Replication: ${REPLICATION_STATUS} (${REPLICATION_MESSAGE})
SMART: ${SMART_STATUS} (${SMART_MESSAGE})
Scrub: ${SCRUB_STATUS} (${SCRUB_MESSAGE})"

    if [ "$overall_status" -eq 0 ]; then
        send_gotify 2 \
            "Backup TrueNAS" \
            "Backup completed successfully.

${notification}

System will shutdown."
    else
        failed_steps="${failed_steps%, }"

        send_gotify 5 \
            "Backup TrueNAS" \
            "Backup completed with failures: ${failed_steps}.

${notification}

System will shutdown."
    fi

    ########################################################################
    # Shutdown
    ########################################################################

    safe_shutdown

    log "${BLUE}==========================================${NC}"

    if [ "$overall_status" -eq 0 ]; then
        log "${GREEN}Script Finished - Status: SUCCESS${NC}"
    else
        log "${YELLOW}Script Finished - Status: PARTIAL FAILURE${NC}"
    fi

    log "${BLUE}==========================================${NC}"
    log ""

    exit "$overall_status"
}

main "$@"
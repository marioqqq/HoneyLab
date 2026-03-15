#!/bin/bash

################################################################################
# TrueNAS Maintenance Script - MAIN MACHINE
# 
# Purpose: Automated SMART testing for main TrueNAS machine
# - Runs SMART tests on NVMe drives ONLY
# - Tests every 30 days (1 month)
# - Sends TrueNAS alerts
# - Does NOT shutdown (main machine stays on)
# - Does NOT run scrub (managed by TrueNAS itself)
#
# Schedule: Run on saturday via cron
# Machine: Main TrueNAS (always on)
#
# Installation:
# 1. Copy to /root/scripts/Main.sh
# 2. chmod 700 /root/scripts/Main.sh
# 3. Add to cron: 0 0 * * 5 /root/scripts/Main.sh
################################################################################

set -uo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - UPDATE IF NEEDED
MIN_DAYS_BETWEEN_SMART=30         # Minimum days between SMART tests (1 month)

# System variables - DO NOT CHANGE
LOG_FILE="/var/log/truenas_maintenance_$(date +%Y%m%d_%H%M%S).log"

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
    midclt call alert.oneshot_create "$level" "$alert_text" 2>&1 | tee -a "$LOG_FILE" || log "${RED}Failed to send alert${NC}"
}

################################################################################
# Main Functions
################################################################################

run_smart_tests() {
    log "${BLUE}=== SMART Tests (NVMe Only) ===${NC}"
    
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
    
    # Test NVMe drives ONLY
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
    
    if [ $tests_started -gt 0 ]; then
        # Record test time
        echo "$current_time" > "$last_test_file"
        log "Started ${GREEN}$tests_started${NC} NVMe SMART tests (${RED}$tests_failed${NC} failed)"
        send_alert "INFO" "SMART Tests" "Started $tests_started NVMe SMART tests"
        return 0
    else
        log "${YELLOW}No NVMe drives found${NC}"
        send_alert "WARNING" "SMART Tests" "No NVMe drives found"
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    log ""
    log "${BLUE}==========================================${NC}"
    log "${BLUE}TrueNAS SMART Test Script Started${NC}"
    log "${BLUE}==========================================${NC}"
    
    send_alert "INFO" "SMART Test Started" "NVMe SMART test process has begun"
    
    local overall_status=0
    
    if ! run_smart_tests; then
        overall_status=1
        log "${YELLOW}⚠${NC} SMART tests failed or skipped"
    fi
    
    if [ $overall_status -eq 0 ]; then
        send_alert "INFO" "SMART Test Complete" "NVMe SMART tests completed successfully"
    else
        send_alert "WARNING" "SMART Test Issues" "Check logs at $LOG_FILE for details"
    fi
    
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
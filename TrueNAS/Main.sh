#!/bin/bash

################################################################################
# TrueNAS NVME SMART Script - MAIN MACHINE
#
# Purpose: Automated NVME SMART testing for Main TrueNAS machine
# - Runs SMART tests on NVMe drives ONLY
# - Tests every 30 days (1 month)
# - Waits for SMART tests to finish
# - Sends one Gotify notification with final result
# - Does NOT shutdown (Main machine stays on)
# - Does NOT run scrub (Main handles scrub)
#
# Schedule: Run daily via cron (recommended: 02:00)
# Machine: Main TrueNAS (always on)
#
# Installation:
# 1. Copy to /root/scripts/Main.sh
# 2. chmod 700 /root/scripts/Main.sh
# 3. Add to cron: 0 2 * * * /root/scripts/Main.sh
################################################################################

set -uo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Gotify configuration
GOTIFY_URL="https://gotify.example.com"
GOTIFY_TOKEN="YOUR_APP_TOKEN"

# Configuration - UPDATE IF NEEDED
MIN_DAYS_BETWEEN_SMART=30
SMART_POLL_INTERVAL=10
SMART_TIMEOUT=1800

# System variables - DO NOT CHANGE
LOG_FILE="/var/log/smart_$(date +%Y%m%d_%H%M%S).log"

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
# Main Functions
################################################################################

run_smart_tests() {
    log "${BLUE}=== SMART Tests (NVMe Only) ===${NC}"

    # Check last SMART test time
    local last_test_file="/var/log/.last_smart_test"
    local current_time=$(date +%s)

    if [ -f "$last_test_file" ]; then
        local last_test_time=$(cat "$last_test_file")
        local days_since=$(( (current_time - last_test_time) / 86400 ))

        log "Last SMART test: ${YELLOW}$days_since days ago${NC}"

        if [ "$days_since" -lt "$MIN_DAYS_BETWEEN_SMART" ]; then
            log "${GREEN}✓${NC} SMART tests not needed (minimum $MIN_DAYS_BETWEEN_SMART days between tests)"
            SMART_STATUS="skipped"
            return 0
        fi
    else
        log "No previous SMART test record found"
    fi

    local tests_started=0
    local tests_failed=0
    local test_devices=()

    ########################################################################
    # Start tests
    ########################################################################

    for dev in /dev/nvme*n1; do
        [ -e "$dev" ] || continue

        local disk
        disk=$(basename "$dev")

        log "Starting NVMe self-test on ${YELLOW}$disk${NC}"

        if nvme device-self-test "$dev" -s 1 >/dev/null 2>&1; then
            log "  ${GREEN}✓${NC} NVMe self-test started on $disk"

            test_devices+=("$dev")
            ((tests_started++))
        else
            log "  ${RED}⚠${NC} Failed to start NVMe self-test on $disk"
            ((tests_failed++))
        fi
    done

    if [ "$tests_started" -eq 0 ]; then
        log "${RED}No NVMe SMART tests could be started${NC}"

        SMART_STATUS="failure"
        SMART_MESSAGE="No NVMe SMART tests could be started."

        return 1
    fi

    log "Started ${GREEN}$tests_started${NC} NVMe SMART tests"
    log "${BLUE}Waiting for tests to finish...${NC}"

    ########################################################################
    # Wait for all tests
    ########################################################################

    local wait_start
    wait_start=$(date +%s)

    while true; do
        local tests_running=0

        for dev in "${test_devices[@]}"; do
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
                log "${YELLOW}⚠${NC} Unable to read self-test status for $(basename "$dev")"
                ((tests_running++))
                continue
            fi

            if (( operation != 0 )); then
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

            SMART_STATUS="failure"
            SMART_MESSAGE="NVMe SMART tests did not finish within $((SMART_TIMEOUT / 60)) minutes."

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

    for dev in "${test_devices[@]}"; do
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

    ########################################################################
    # Final result
    ########################################################################

    local total_failed=$((tests_failed + tests_result_failed))

    if [ "$total_failed" -eq 0 ]; then
        echo "$current_time" > "$last_test_file"

        SMART_STATUS="success"
        SMART_MESSAGE="SMART tests completed successfully on $tests_passed NVMe drives."

        log "${GREEN}✓ All $tests_passed NVMe SMART tests passed${NC}"

        return 0
    else
        SMART_STATUS="failure"
        SMART_MESSAGE="$tests_passed NVMe drives passed, $total_failed failed."

        log "${RED}⚠ NVMe SMART tests finished with failures${NC}"

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

    SMART_STATUS=""
    SMART_MESSAGE=""

    local overall_status=0

    if ! run_smart_tests; then
        overall_status=1
    fi

    ########################################################################
    # Send ONE notification after tests have finished
    ########################################################################

    case "$SMART_STATUS" in
        success)
            send_gotify 2 \
                "Main TrueNAS SMART" \
                "$SMART_MESSAGE"
            ;;

        failure)
            send_gotify 5 \
                "Main TrueNAS SMART" \
                "$SMART_MESSAGE Check $LOG_FILE for details."
            ;;

        skipped)
            # No notification when test is not due
            ;;
    esac

    log "${BLUE}==========================================${NC}"

    if [ "$overall_status" -eq 0 ]; then
        log "${GREEN}Script Finished - Status: SUCCESS${NC}"
    else
        log "${RED}Script Finished - Status: FAILURE${NC}"
    fi

    log "${BLUE}==========================================${NC}"
    log ""

    exit "$overall_status"
}

main "$@"
#!/usr/bin/env bash

# Filename: /auto-pr-approval/test_main.sh
# Description:

LOG_LEVEL="INFO"  # Default log level
LOG_TO_CONSOLE=false  # Default: don't log to console

# Define log levels
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARNING]=2
    [ERROR]=3
)

# Parse arguments to set log level and log-to-console option
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --log-level)
                shift
                if [[ -n "$1" ]] && [[ "${LOG_LEVELS[$1]}" ]]; then
                    LOG_LEVEL="$1"
                else
                    echo "Invalid log level: $1. Valid options are: DEBUG, INFO, WARNING, ERROR."
                    exit 1
                fi
                ;;
            --log-to-console)
                LOG_TO_CONSOLE=true
                ;;
            --help|-h)
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console]"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console]"
                exit 1
                ;;
        esac
        shift
    done
}

# Log message function
lm() {
    local level=$1
    local message=$2

    if (( LOG_LEVELS[$level] >= LOG_LEVELS[$LOG_LEVEL] )); then
        logger -t "smoked-auto-pr-approval-$level" "$message"
        if [[ "$LOG_TO_CONSOLE" == true ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
        fi
    fi
}

test_single_admin() {
    TEST_BRANCH="smoke-test-$(date +%s)"
    git checkout -b "$TEST_BRANCH" || { echo "Failed to switch to $TEST_BRANCH"; exit 1; }
    # make a change
    # stage and commit change
    # push change to origin
    # create pr
    # capture confirmation that the pr was approved || lm

}

test_more_than_one_admin() {

}

main() {
    parse_arguments "$@"
    CURRENT_BRANCH=$(git branch --show-current) || { echo "Not in git repo; exiting."; exit 0; }
    trap teardown EXIT
    if test_single_admin; then
        lm success
    else
        lm failure
    if test_two_admins; then
        lm success
    else
        lm failure
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi


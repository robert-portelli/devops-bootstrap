#!/usr/bin/env bash

# Filename: manage-smoke-tests.sh
# Description: Automates the creation, staging, and testing of smoke tests for pre-commit hooks.
# Supports multiple repositories dynamically defined in the SUPPORTED_REPOS array.

declare -A PATHS

LOG_LEVEL="INFO" # Default log level

# Define log levels
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARNING]=2
    [ERROR]=3
)

# Parse arguments to set log level
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
            --help|-h)
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}]"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}]"
                exit 1
                ;;
        esac
        shift
    done
}

# Log message with levels
lm() {
    local level="$1"
    local message="$2"

    if (( LOG_LEVELS[$level] >= LOG_LEVELS[$LOG_LEVEL] )); then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "${PATHS[log_file]}"
    fi
}

log_rotate() {
    local old_logs_to_keep=5  # Number of old logs to retain

    # Move all logs from log_dir to old_logs
    for file in "${PATHS[log_dir]}"/*.log; do
        [[ -f "$file" ]] && mv "$file" "${PATHS[old_logs]}"
        lm DEBUG "Moved $file to old_logs"
    done

    # Get a sorted list of all logs in old_logs
    local all_logs=("${PATHS[old_logs]}"/*.log)
    local total_logs=${#all_logs[@]}

    # Check if the number of logs exceeds the threshold
    if (( total_logs > old_logs_to_keep )); then
        # Calculate how many logs to remove
        local logs_to_remove=$((total_logs - old_logs_to_keep))

        # Remove the oldest logs
        for (( i = 0; i < logs_to_remove; i++ )); do
            lm DEBUG "Deleted old_log: ${all_logs[i]}"
            rm -f "${all_logs[i]}"
        done
    fi
}

# Centralize path management
define_paths() {
    # "repo" refers to the repos listed in .pre-commit-config.yaml
    local REPO="$1"
    # the path to the directory from which this script is called
    local script_dir
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    local repo_dir
    repo_dir="${script_dir}/${REPO}"

    PATHS[repo_dir]="$repo_dir"
    PATHS[log_dir]="${repo_dir}/log"
    PATHS[log_file]="${script_dir}/${REPO}/log/$(date '+%Y-%m-%d_%H-%M-%S')_smoke-test.log"
    PATHS[old_logs]="${repo_dir}/log/old"
    PATHS[smoke_tests]="${repo_dir}/smoke-tests"
    PATHS[create_smoke_tests]="${repo_dir}/create-smoke-tests.sh"

    mkdir -p "${PATHS[log_dir]}" "${PATHS[old_logs]}" "${PATHS[smoke_tests]}"
    lm DEBUG "$(declare -p PATHS)"
}

create_smoke_tests() {
    # use the repository's script to create smoke tests
    local REPO="$1"
    local PATH="${PATHS[create_smoke_tests]}"
    if [[ -x "$PATH" ]]; then
        bash "$PATH" && lm DEBUG "Created smoke tests for $REPO."
    else
        lm WARNING "Warning: $PATH not found or not executable for $REPO."
    fi
}

stage_smoke_tests() {
    # some hooks require files to be staged for analysis
    local REPO="$1"
    local PATH="${PATHS[smoke_tests]}"
    git add --force "$PATH"/* || lm ERROR "Failed to stage smoke tests for $REPO."
}

cleanup_smoke_tests() {
    local PATH="${PATHS[smoke_tests]}"
    [[ -d "$PATH" ]] && rm -rf "$PATH"
    lm DEBUG "Cleaned up smoke tests directory: $PATH"
}

teardown() {
    if [[ -z "$CURRENT_BRANCH" ]]; then
        lm INFO "No cleanup necessary; exiting."
        exit
    fi
    # Return to the original branch
    git checkout "$CURRENT_BRANCH" ||  { lm ERROR "Failed to switch to $CURRENT_BRANCH"; return 1; }
    git branch -D "$TEST_BRANCH" || lm ERROR "Failed to delete $TEST_BRANCH"
    git push origin --delete "$TEST_BRANCH" || lm WARNING "No remote branch to delete."
}


main() {
    parse_arguments "$@"

    SUPPORTED_REPOS=(
        # Add repository names here
        "pre-commit-repo"
    )

    if [[ "${#SUPPORTED_REPOS[@]}" -eq 0 ]]; then
        echo  "No repositories to test; exiting."
        exit 0
    fi

    CURRENT_BRANCH=$(git branch --show-current) || { echo "Not in git repo; exiting."; exit 0; }

    trap teardown EXIT

    TEST_BRANCH="smoke-test-$(date +%s)"
    git checkout -b "$TEST_BRANCH" || { echo "Failed to switch to $TEST_BRANCH"; exit 1; }

    for REPO in "${SUPPORTED_REPOS[@]}"; do
            define_paths "$REPO" || { echo "path definitions failed for $REPO; skipping."; lm "path definitions failed for $REPO"; continue; }
            log_rotate "$REPO"
            create_smoke_tests "$REPO" || { lm ERROR "failed to create smoke tests for $REPO"; continue; }
            stage_smoke_tests "$REPO"
            lm INFO "=== Starting Smoke Tests ==="
            pre-commit run --files "${PATHS[smoke_tests]}"/* --verbose || lm "pre-commit ran on smoke tests"
            lm INFO "=== Smoke Tests Complete ==="
            cleanup_smoke_tests
        done
}

# Check if the script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#    alias lm="log_message"
    main "$@"
fi

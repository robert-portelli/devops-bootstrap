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

#log message
lm() {
    local level="$1"  # Log level (e.g., DEBUG, INFO, ERROR)
    local message="$2"  # Message to log

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
    PATHS[pc_config]="${repo_dir}/.ST-pre-commit-config.yaml"  # Entry for .ST-pre-commit-config.yaml

    mkdir -p "${PATHS[log_dir]}" "${PATHS[old_logs]}" "${PATHS[smoke_tests]}"
#    lm DEBUG $(log_paths)
}


create_smoke_tests() {
    # use the repository's script to create smoke tests
    local REPO="$1"
    local create_smokes_script="${PATHS[create_smoke_tests]}"
    if [[ -x "$create_smokes_script" ]]; then
        bash "$create_smokes_script" && lm DEBUG "Created smoke tests for $REPO."
    else
        lm WARNING "Warning: $create_smokes_script not found or not executable for $REPO."
    fi
}

stage_smoke_tests() {
    # some hooks require files to be staged for analysis
    local REPO="$1"
    local smokes_dir="${PATHS[smoke_tests]}"
    git add --force "$smokes_dir"/* || lm ERROR "Failed to stage smoke tests for $REPO."
}

cleanup_smoke_tests() {
    local smokes_dir="${PATHS[smoke_tests]}"
    [[ -d "$smokes_dir" ]] && rm -rf "$smokes_dir"
    lm DEBUG "Cleaned up smoke tests directory: $smokes_dir"
}

run_pre_commit() {
    local REPO="$1"
    local config_path="${PATHS[pc_config]}"
    local smoke_tests="${PATHS[smoke_tests]}"

    if [[ ! -f "$config_path" ]]; then
        lm ERROR "Pre-commit config not found: $config_path"
        return 1
    fi

    lm INFO "Running pre-commit using config: $config_path"
    for file in "$smoke_tests"/*; do
        if [[ -f "$file" ]]; then
            lm INFO "Running pre-commit for $file using config: $config_path"
            pre-commit run --config "$config_path" --files "$file" --verbose || lm WARNING "Pre-commit failed for $file"
        fi
    done
}

teardown() {
    if [[ -z "$CURRENT_BRANCH" ]]; then
        lm INFO "No cleanup necessary; exiting."
        exit
    fi
    cleanup_smoke_tests
    git restore --staged .
    git restore .
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
        "yamlfmt-repo"
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
            #lm DEBUG "$(declare -p PATHS)" || lm DEBUG "Failed to log PATHS array."
            log_rotate "$REPO"
            create_smoke_tests "$REPO" || { lm ERROR "failed to create smoke tests for $REPO"; continue; }
            stage_smoke_tests "$REPO"
            lm INFO "=== Starting Smoke Tests ==="
            run_pre_commit "$REPO"
            lm INFO "=== Smoke Tests Complete ==="
            #cleanup_smoke_tests
        done
}

# Check if the script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#    alias lm="log_message"
    main "$@"
fi

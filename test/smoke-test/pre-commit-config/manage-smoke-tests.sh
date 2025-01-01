#!/usr/bin/env bash

# Filename: manage-smoke-tests.sh
# Description: Automates the creation, staging, and testing of smoke tests for pre-commit hooks.
# Supports multiple repositories dynamically defined in the SUPPORTED_REPOS array.

declare -A PATHS

# Centralize path management
define_paths() {
    # "repo" refers to the repos listed in .pre-commit-config.yaml
    local REPO="$1"
    # the path to the directory from which this script is called
    local script_dir
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    PATHS=(
        [repo_dir]="${script_dir}/${REPO}"
        [log_dir]="${repo_dir}/log"
        [log_file]="${script_dir}/${REPO}/log/$(date '+%Y-%m-%d_%H-%M-%S')_smoke-test.log"
        [old_logs]="${repo_dir}/log/old"
        [smoke_tests]="${repo_dir}/smoke-tests"
        [create_smoke_tests]="${repo_dir}/create-smoke-tests.sh"
    )

    mkdir -p "${PATHS[log_dir]}" "${PATHS[old_logs]}" "${PATHS[smoke_tests]}"
}

log_rotate() {
    local old_logs_to_keep=5  # Number of old logs to retain

    # Move all logs from log_dir to old_logs
    for file in "${PATHS[log_dir]}"/*.log; do
        [[ -f "$file" ]] && mv "$file" "${PATHS[old_logs]}"
    done

    # Keep the youngest `old_logs_to_keep` logs and delete the rest
    local all_logs=("${PATHS[old_logs]}"/*.log)
    if (( ${#all_logs[@]} > old_logs_to_keep )); then
        # Sort logs by modification time (newest last) and remove the oldest
        ls -t "${PATHS[old_logs]}"/*.log | tail -n +$((old_logs_to_keep + 1)) | xargs rm -f
    fi
}


log_message() {
    local message="$1"
    echo "$message" >> "${PATHS[log_file]}"
}


create_smoke_tests() {
    # use the repository's script to create smoke tests
    local REPO="$1"
    local PATH="${PATHS[create_smoke_tests]}"
    if [[ -x "$PATH" ]]; then
        bash "$PATH" && lm "Created smoke tests for $REPO."
    else
        lm "Warning: $PATH not found or not executable for $REPO."
    fi
}

stage_smoke_tests() {
    local REPO="$1"
    local PATH="${PATHS[smoke_tests]}""
    git add --force "$PATH"/* || lm "Failed to stage smoke tests for $REPO."
}

teardown() {
    if [[ -z "$CURRENT_BRANCH" ]]; then
        lm "No cleanup necessary; exiting."
        exit
    fi
    # Return to the original branch
    git checkout "$CURRENT_BRANCH" ||  { lm "Failed to switch to $CURRENT_BRANCH"; return 1; }

    # Delete the smoke test branch
    git branch -D "$TEST_BRANCH" || lm "Failed to delete $TEST_BRANCH"
    git push origin --delete "$TEST_BRANCH" || lm "No remote branch to delete."
}


main() {
    SUPPORTED_REPOS=(
        # Add repository names here
        "pre-commit-repo"
    )

    if [[ ${#SUPPORTED_REPOS[@]} -eq 0 ]]; then
        echo  "No repositories to test; exiting."
        exit 0
    fi

    CURRENT_BRANCH=$(git branch --show-current) || { echo "Not in git repo; exiting."; exit 0; }

    trap teardown EXIT

    TEST_BRANCH="smoke-test-$(date +%s)"
    git checkout -b "$TEST_BRANCH" || { echo "Failed to switch to $TEST_BRANCH"; exit 1; }
    alias lm="log_message"

    for REPO in "${SUPPORTED_REPOS[@]}"; do
            # each repo has its own directory and therefore its own log dir and logs
            local log_file
            log_file=$(log_setup "$REPO") || { echo "log setup failed for $REPO; skipping."; lm "log setup failed for $REPO"; continue; }
            lm "=== Starting Smoke Tests ==="
            local smoke_tests
            smoke_tests=$(create_smoke_tests "$REPO") || { lm "failed to create smoke tests for $REPO"; continue; }
            stage_smoke_tests "$smoke_tests" # to smoke test files that require staging
            pre-commit run --files "$smoke_tests"/* --verbose || lm "pre-commit ran on smoke tests"
            stage_smoke_tests "$smoke_tests" # for modified file cleanup
            lm "=== Smoke Tests Complete ==="
        done
}

# Check if the script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

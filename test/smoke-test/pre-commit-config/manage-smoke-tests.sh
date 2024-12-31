#!/usr/bin/env bash

# Filename: manage-smoke-tests.sh
# Description: Automates the creation, staging, and testing of smoke tests for pre-commit hooks.
# Supports multiple repositories dynamically defined in the SUPPORTED_REPOS array.

log_setup() {
    # Get the script's directory
    local script_dir
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Create directories for logs
    local log_dir="${script_dir}/log"
    local old_logs="${log_dir}/old"
    mkdir -p "$log_dir" "$old_logs"

    # Archive old logs
    for file in "$log_dir"/*.log; do
        [[ -f "$file" ]] &&  mv "$file" "$old_logs/"
    done

    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')

    # return the log_file
    echo "${log_dir}/${timestamp}_smoke-test.log"
}

log_message() {
    local message="$1"
    echo "$message" >> "$log_file"
}

alias lm="log_message"

create_smoke_tests() {
    for REPO in "${SUPPORTED_REPOS[@]}"; do
        local script="test/smoke-test/pre-commit-config/$REPO/create-smoke-tests.sh"
        if [[ -x "$script" ]]; then
            bash "$script" && lm "Created smoke tests for $REPO."
        else
            lm "Warning: $script not found or not executable for $REPO."
        fi
    done
}

stage_smoke_tests() {
    for REPO in "${SUPPORTED_REPOS[@]}"; do
        git add --force "test/smoke-test/pre-commit-config/$REPO/"* || lm "Failed to stage smoke tests for $REPO."
    done
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
    CURRENT_BRANCH=$(git branch --show-current) || { echo "No git branch available."; exit 1; }
    trap teardown EXIT # avoid unnecessarily running teardown if CURRENT_BRANCH is unset

    log_file=$(log_setup) || { echo "log_setup() failed."; exit 1; }
    lm "=== Starting Smoke Tests ==="

    SUPPORTED_REPOS=(
        # Add repository names here
        "pre-commit-repo"
    )

    if [[ ${#SUPPORTED_REPOS[@]} -eq 0 ]]; then
        lm "No repositories to test; exiting."
        exit 0
    fi

    # Create a new branch for smoke testing
    TEST_BRANCH="smoke-test-$(date +%s)"
    git checkout -b "$TEST_BRANCH" || { lm "Failed to switch to $TEST_BRANCH"; exit 1; }

    create_smoke_tests
    stage_smoke_tests

    pre-commit run --all-files --verbose || lm "pre-commit ran on smoke tests"
    lm "=== Smoke Tests Complete ==="
}

# Check if the script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi

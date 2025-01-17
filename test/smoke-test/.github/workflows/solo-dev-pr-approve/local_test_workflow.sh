#!/usr/bin/env bash

# Filename: /test/smoke-test/.github/workflows/solo-dev-pr-approve/local_test_workflow.sh
# Description:
#   This script serves as the local testing entry point for verifying the
#   'solo-dev-pr-approve.yaml' GitHub Actions workflow. It facilitates the
#   setup and execution of BATS (Bash Automated Testing System) tests with
#   configurable logging and optional BATS-specific flags for debugging.
#
# Purpose:
#   - Streamline local testing of GitHub Actions workflows.
#   - Enable dynamic configuration of test environments and verbosity levels.
#   - Integrate reusable components such as Docker, `act`, and BATS.
#   - Allow flexible passing of additional BATS flags for advanced debugging
#     or output configuration.
#   - Facilitate debugging and validation of workflow logic by emulating
#     GitHub Actions environment locally.
#
# Usage:
#   bash test/smoke-test/.github/workflows/solo-dev-pr-approve/local_test_workflow.sh [options]
#
# Options:
#   --log-level {DEBUG|INFO|WARNING|ERROR}  Set the logging level (default: INFO).
#   --log-to-console                        Enable logging to the console (default: false).
#   --bats-flags "<flags>"                  Pass additional flags to the BATS test framework.
#                                           The flags should be enclosed in quotes if they contain spaces.
#
# Examples:
#   # Run tests with DEBUG log level and additional BATS flags
#   bash test/smoke-test/.github/workflows/solo-dev-pr-approve/local_test_workflow.sh \
#       --log-to-console \
#       --log-level DEBUG \
#       --bats-flags "--verbose-run --show-output-of-passing-tests"
#
#   # Run tests with default log level and no additional BATS flags
#   bash test/smoke-test/.github/workflows/solo-dev-pr-approve/local_test_workflow.sh
#
# Requirements:
#   - Docker installed and running.
#   - `act` installed as a GitHub CLI extension and configured.
#   - GitHub repository must have the workflow files correctly placed.
#
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/devops-bootstrap
# Version:
#   See repository tags or release notes.
# License:
#   See repository license file (e.g., LICENSE.md).
# Last Updated:
#   See repository commit history (e.g., `git log`).


LOG_LEVEL="INFO"  # Default log level
LOG_TO_CONSOLE=false  # Default: don't log to console
BATS_FLAGS=""

# Define log levels
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARNING]=2
    [ERROR]=3
)

# Parse arguments to set log level, log-to-console option, and bats flags
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --log-level)
                shift
                if [[ -n "$1" ]] && [[ "${LOG_LEVELS[$1]}" ]]; then
                    LOG_LEVEL="$1"
                    shift
                else
                    echo "Invalid log level: $1. Valid options are: DEBUG, INFO, WARNING, ERROR."
                    exit 1
                fi
                ;;
            --log-to-console)
                LOG_TO_CONSOLE=true
                shift
                ;;
            --bats-flags)
                shift
                if [[ -n "$1" ]]; then
                    BATS_FLAGS="$1"
                    shift
                else
                    echo "Error: No flags provided after --bats-flags."
                    exit 1
                fi
                ;;
            --help|-h)
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console] [--bats-flags '<flags>']"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console] [--bats-flags '<flags>']"
                exit 1
                ;;
        esac
    done
}


# Log message function
lm() {
    local level=$1
    local message=$2

    if (( LOG_LEVELS[$level] >= LOG_LEVELS[$LOG_LEVEL] )); then
        logger -t "solo-dev-pr-approve-$level" "$message"
        if [[ "$LOG_TO_CONSOLE" == true ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
        fi
    fi
}


# data structure for script assets
declare -A ASSETS

assets_define() {
    local git_repo
    git_repo=$(git rev-parse --show-toplevel)

    ASSETS[git_repo]="$git_repo"
    ASSETS[tests]="${git_repo}/test/smoke-test/.github/workflows/solo-dev-pr-approve/tests.bats"
    ASSETS[imagename]="robertportelli/my-custom-act-image:latest"
    ASSETS[dockerimage]="ubuntu-latest=${ASSETS[imagename]}"
    ASSETS[imagepath]="${git_repo}/docker-custom-act/Dockerfile"
    #ASSETS[actioncache]="${git_repo}/test/smoke-test/.cache/act"
    #ASSETS[cacheserverpath]="${git_repo}/test/smoke-test/.cache/actcache"
    #ASSETS[cacheserveraddr]="127.0.0.1"

    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        assets_log
    fi
}

assets_log() {
    if [[ "$(declare -p ASSETS 2>/dev/null)" =~ "declare -A" ]]; then
        for key in "${!ASSETS[@]}"; do
            lm DEBUG "ASSETS[$key] = ${ASSETS[$key]}"
        done
    else
        lm ERROR "ASSETS is not defined or not an associative array."
    fi
}

cleanup() {
    local containers
    containers=$(docker ps -a -q --filter ancestor="${ASSETS[imagename]}")

    if [[ -n "$containers" ]]; then
        echo "Removing containers created from image '${ASSETS[imagename]}'..."
        docker rm -f "$containers"
    else
        echo "No containers found for image '${ASSETS[imagename]}'."
    fi
}

run_tests() {
    (
        export customimage="${ASSETS[dockerimage]}"
        if [[ -n "$BATS_FLAGS" ]]; then
            bats $BATS_FLAGS "${ASSETS[tests]}"
        else
            bats "${ASSETS[tests]}"
        fi
    )
}

main() {
    parse_arguments "$@"
    assets_define || lm ERROR "Failed to define script assets."
    readonly -A ASSETS
    trap cleanup EXIT
    run_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

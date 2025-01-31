#!/usr/bin/env bash

# Filename: /test/smoke-test/.github/actions/environment-setup/test_action.sh
# Description: This script runs a smoke test for the "environment setup" GitHub Action by invoking `act` to simulate workflow execution locally.
# Purpose: To validate that the environment setup action workflow runs successfully in a local environment using the `act` tool.
# Usage:
#   bash test/smoke-test/.github/actions/environment-setup/test_action.sh [options]
# Options:
#   --log-level {DEBUG|INFO|WARNING|ERROR}  Set the logging level (default: INFO).
#   --log-to-console                        Enable logging to the console (default: false).
# Requirements:
#   - Docker installed and running
#   - `act` CLI installed and configured
#   - GitHub repository must have the workflow files correctly placed
# Author: Robert Portelli
# Repository: https://github.com/robert-portelli/devops-bootstrap
# Version: See repository tags or release notes
# License: See repository license file (e.g., LICENSE.md)
# Last Updated: See repository commit history (e.g., `git log`)

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
        logger -t "smoked-environment-setup-action-$level" "$message"
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
    ASSETS[workflow]="${git_repo}/test/smoke-test/.github/actions/environment-setup/test-workflow-for-action.yaml"
    ASSETS[imagename]="robertportelli/my-custom-act-image:latest"
    ASSETS[dockerimage]="ubuntu-latest=${ASSETS[imagename]}"
    ASSETS[imagepath]="${git_repo}/docker-custom-act/Dockerfile"
    ASSETS[actioncache]="${git_repo}/test/smoke-test/.cache/act"
    ASSETS[cacheserverpath]="${git_repo}/test/smoke-test/.cache/actcache"
    ASSETS[cacheserveraddr]="127.0.0.1"

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

smoke_test_environment_setup() {
    lm INFO "Running smoke test for environment setup."
    gh act \
        -j "test-environment-setup-action" \
        -P "${ASSETS[dockerimage]}" \
        -W "${ASSETS[workflow]}" \
        --pull "false" \
        --action-cache-path "${ASSETS[actioncache]}" \
        --cache-server-path "${ASSETS[cacheserverpath]}" \
        --cache-server-addr "${ASSETS[cacheserveraddr]}" \
        --action-offline-mode \
        --bind
}

main() {
    parse_arguments "$@"
    assets_define || lm ERROR "Failed to define script assets."
    readonly -A ASSETS
    trap cleanup EXIT
    smoke_test_environment_setup
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

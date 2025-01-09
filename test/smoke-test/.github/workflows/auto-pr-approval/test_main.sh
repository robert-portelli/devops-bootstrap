#!/usr/bin/env bash

# Filename: /auto-pr-approval/test_main.sh
# Description:
# This script performs a smoke test of the GitHub Actions workflow for auto-approving pull requests.
# It builds a custom Docker image (if necessary), runs `act` to simulate the GitHub Actions runner locally,
# and cleans up any containers created during the test. Logging levels and options for console output are configurable.
#
# Purpose:
# - Define and build the Docker image used for testing the workflow.
# - Run a smoke test using `gh act` to simulate the workflow.
# - Clean up any resources after the test (Docker containers).
#
# Usage:
# ./test_main.sh [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console]
#
# Options:
# --log-level      Set the logging level (default: INFO).
# --log-to-console Output log messages to the console instead of only sending them to the system logger.
# --help, -h       Display this help message.
#
# Requirements:
# - Docker installed and running.
# - GitHub CLI (`gh`) installed and authenticated.
# - `act` installed as a `gh` extension or via package manager.
#
# Author: Robert Portelli
# Repository: https://github.com/robert-portelli/devops-bootstrap
# Version: See repository tags or release notes
# License: See repository license file (e.g., LICENSE.md)
# Last Updated: See repository commit history (e.g., git log)


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


# data structure for script assets
declare -A ASSETS

assets_define() {
    local git_repo
    git_repo=$(git rev-parse --show-toplevel)

    ASSETS[git_repo]="$git_repo"
    ASSETS[workflow]="${git_repo}/.github/workflows/auto-pr-approval.yaml"
    ASSETS[events]="${git_repo}/test/smoke-test/.github/workflows/auto-pr-approval/events"
    ASSETS[imagename]="robertportelli/my-custom-act-image:latest"
    ASSETS[dockerimage]="ubuntu-latest=${ASSETS[imagename]}"
    ASSETS[imagepath]="${git_repo}/docker-custom-act/Dockerfile"

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

build_image() {
    if [[ -n $(docker images --filter=reference="${ASSETS[imagename]}" -q) ]]; then
        lm INFO "Docker image '${ASSETS[imagename]}' already exists. Skipping build."
    else
        lm INFO "Docker image '${ASSETS[imagename]}' not found. Building the image..."
        DOCKER_BUILDKIT=1 \
        docker build --load \
            -t "${ASSETS[imagename]}" \
            -f "${ASSETS[imagepath]}" \
            "$(dirname "${ASSETS[imagepath]}")"
    fi
}

smoke_test_admin_count() {
    local admin_count=$1
    lm INFO "Running smoke test with $admin_count admin(s)."
    gh act \
        -j "auto-approve" \
        -P "${ASSETS[dockerimage]}" \
        -W "${ASSETS[workflow]}" \
        --pull "false" \
        -e "${ASSETS[events]}/pull_request.json" \
        --env MOCK_ADMIN_COUNT="$admin_count" \
        --env GITHUB_TOKEN="$(gh auth token)" \
        --env GH_TOKEN="$(gh auth token)" \
        --secret GITHUB_TOKEN="$(gh auth token)"
}

#smoke_test_simple() {
#    lm INFO "Running simple smoke test"
#    gh act \
#        -j "smoke-test" \
#        -P "${ASSETS[dockerimage]}" \
#        -W "${ASSETS[git_repo]}/.github/workflows/simple.yaml" \
#        --pull "false" \
#        -e "${ASSETS[git_repo]}/pull_request.json" \
#        --env GITHUB_TOKEN="$(gh auth token)"
#}

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

main() {
    parse_arguments "$@"
    assets_define || lm ERROR "Failed to define script assets."
    readonly -A ASSETS
    #build_image || lm ERROR "Failed to build image."
    trap cleanup EXIT
    smoke_test_admin_count 1
    #smoke_test_admin_count 2
    #smoke_test_simple
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#!/usr/bin/env bash
# Filename: test/smoke-test/.github/workflows/solo-dev-pr-approve/tests.bats
# Description:
#   This script contains BATS tests to verify the functionality of the
#   'solo-dev-pr-approve.yaml' GitHub Actions workflow. It uses `gh act`
#   to simulate workflow execution in a local environment with mock data.
#
# Usage:
#   Called by `test_workflow.sh` as part of the testing pipeline.
#
# Dependencies:
#   - BATS (Bash Automated Testing System) installed.
#   - `gh` CLI installed and authenticated.
#   - `act` GitHub Actions emulator installed and configured.
#   - Mock event JSON files and required secrets available.
#
# Functions:
#   - setup:
#       Sets up the testing environment, including loading helper scripts.
#   - call_act:
#       Executes the specified job from the workflow using `gh act`.
#
# Test Cases:
#   - "true BATS smoke test": Basic test to verify the BATS framework.
#   - "PR approved open": Validates the 'check-pr-readiness' job in the workflow
#     using a simulated 'PR approved' event JSON.
#
# Example:
#   ./test_workflow.sh --log-level DEBUG --log-to-console
#
# Notes:
#   - Ensure all required secrets are set in the environment or accessible
#     from secure locations defined in the script.
#   - Verbosity for `gh act` can be enabled by passing "true" to the `call_act` function.
#
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/devops-bootstrap
#   Version: See repository tags or release notes.
#   License: See repository license file (e.g., LICENSE.md)

EVENTS_DIR=""

function setup {
    echo "Setting up testing environment..."
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "Error: Could not determine project root. Exiting." >&2
        exit 1
    }
    echo "Project root determined: $GIT_ROOT"
    EVENTS_DIR="${GIT_ROOT}/test/smoke-test/.github/workflows/solo-dev-pr-approve/events"
    echo "Events directory set to: $EVENTS_DIR"
    load "${GIT_ROOT}/test/test_helpers/_common_setup"
    _common_setup
}

validate_env() {
    # Resolve secrets dynamically, with fallback to local paths
    AUTO_APPROVE_APP_ID="${AUTO_APPROVE_APP_ID:-$(cat /root/secrets/devops-bootstrap/gh_app_ID 2>/dev/null)}"
    AUTO_APPROVE_PRIVATE_KEY="${AUTO_APPROVE_PRIVATE_KEY:-$(cat /root/secrets/devops-bootstrap/auto-approve-prs.2025-01-09.private-key.pem 2>/dev/null)}"
    PERSONAL_ACCESS_TOKEN="${PERSONAL_ACCESS_TOKEN:-$(cat /root/secrets/devops-bootstrap/personal-access-token 2>/dev/null)}"
    GH_TOKEN="${GH_TOKEN:-$(gh auth token 2>/dev/null)}"

    # Check if secrets are resolved
    for secret in AUTO_APPROVE_APP_ID AUTO_APPROVE_PRIVATE_KEY PERSONAL_ACCESS_TOKEN GH_TOKEN; do
        if [[ -z "${!secret}" ]]; then
            echo "Error: Required secret '$secret' is not set, and no local fallback found." >&2
            return 1
        fi
    done

    # Validate event JSON file existence
    [[ -f "$event_path" ]] || fail "Event JSON file not found: $event_path"

    # Ensure `customimage` is available
    [ -n "$customimage" ] || fail "customimage is not set."

}

call_act() {
    local job="$1"
    local event_file="$2"
    local verbose="${3:-false}"
    local event_path="${EVENTS_DIR}/${event_file}"

    # Validate environment and secrets
    validate_env

    # Log details for debugging
    echo "Running 'gh act' for job: $job with event JSON: $event_path"

    # Call act
    run gh act \
        -W ".github/workflows/solo-dev-pr-approve.yaml" \
        -j "$job" \
        -P "$customimage" \
        --pull "false" \
        --eventpath "$event_path" \
        --env GH_TOKEN="$(gh auth token)" \
        --env GITHUB_TOKEN="$(gh auth token)" \
        --secret GITHUB_TOKEN="$(gh auth token)" \
        --secret AUTO_APPROVE_APP_ID="$AUTO_APPROVE_APP_ID" \
        --secret AUTO_APPROVE_PRIVATE_KEY="$AUTO_APPROVE_PRIVATE_KEY" \
        --secret PERSONAL_ACCESS_TOKEN="$PERSONAL_ACCESS_TOKEN" \
        $( [[ "$verbose" == "true" ]] && echo "--verbose" )
}

@test "true BATS smoke test" {
    run true
    [[ "$status" -eq 0 ]]
}

@test "PR approved open" {
    call_act \
        "check-pr-readiness" \
        "pr-approved-open.json"
        "true"

    assert_output --partial "Success - Main Check out the repository"
    assert_output --partial "Repository Owner: nektos/act"
    refute_output --partial "Error: Only the repository owner can trigger this workflow."
}

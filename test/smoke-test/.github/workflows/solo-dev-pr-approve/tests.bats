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

function setup {
    echo "Setting up testing environment..."
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "Error: Could not determine project root. Exiting." >&2
        exit 1
    }
    echo "Project root determined: $GIT_ROOT"
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
    if [[ ! -f "$event_json" ]]; then
        echo "Error: Event JSON file '$event_json' does not exist." >&2
        return 1
    fi
}

call_act() {
    local job="$1"
    local event_json="$2"
    local verbose="${3:-false}"

    # Validate environment and secrets
    validate_env

    # Log details for debugging
    echo "Running 'gh act' for job: $job with event JSON: $event_json"

    # Call act
    run gh act \
        -W ".github/workflows/solo-dev-pr-approve.yaml" \
        -j "$job" \
        -P "robertportelli/custom-image:latest" \
        --env GH_TOKEN="$GH_TOKEN" \
        --eventpath "$event_json" \
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
        "events/pr-approved-open.json" \
        "true"
}

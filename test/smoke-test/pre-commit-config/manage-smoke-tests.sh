#!/usr/bin/env bash

# Filename: manage-smoke-tests.sh
# Description: Automates the creation, staging, and testing of smoke tests for pre-commit hooks.
# Supports multiple repositories dynamically defined in the SUPPORTED_REPOS array.

# Array of supported repositories
SUPPORTED_REPOS=(
)

# Function to create smoke tests
create_smoke_tests() {
    echo "Creating smoke tests..."
    for REPO in "${SUPPORTED_REPOS[@]}"; do
        if [[ -x "test/smoke-test/pre-commit-config/$REPO/create-smoke-tests.sh" ]]; then
            bash "test/smoke-test/pre-commit-config/$REPO/create-smoke-tests.sh"
            echo "Created smoke tests for $REPO."
        else
            echo "Warning: create-smoke-tests.sh not found or not executable for $REPO."
        fi
    done
}

# Function to stage smoke tests
stage_smoke_tests() {
    echo "Staging smoke tests..."
    for REPO in "${SUPPORTED_REPOS[@]}"; do
        git add --force "test/smoke-test/pre-commit-config/$REPO/"*
        echo "Staged smoke tests for $REPO."
    done
}

# Save the current branch name
CURRENT_BRANCH=$(git branch --show-current)

# Create a new branch for smoke testing
TEST_BRANCH="smoke-test-$(date +%s)"
echo "Switching to a new branch: $TEST_BRANCH"
git checkout -b "$TEST_BRANCH"

# Create and stage smoke tests
create_smoke_tests
stage_smoke_tests

if ! pre-commit run --all-files --verbose; then
    echo "Pre-commit hooks failed. Review the output above for details."
    exit 1
fi

# Return to the original branch
echo "Returning to the original branch: $CURRENT_BRANCH"
git checkout "$CURRENT_BRANCH"

# Delete the smoke test branch
echo "Deleting the smoke test branch: $TEST_BRANCH"
git branch -D "$TEST_BRANCH"
git push origin --delete "$TEST_BRANCH" || echo "No remote branch to delete."

echo "Smoke test workflow complete."

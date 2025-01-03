#!/usr/bin/env bash
# Filename: create-smoke-tests.sh
# Description: Creates test cases to validate yamlfmt hook functionality.

# Define the directory to store test cases
SMOKE_TEST_DIR="test/smoke-test/pre-commit-config/yaml-fmt-repo/smoke-tests"

# ensure the directory exists
mkdir -p "$SMOKE_TEST_DIR"
cd SMOKE_TEST_DIR || exit 1

# Test Case 1: Unformatted YAML
cat <<EOL >unformatted.yaml
key1: value1
key2:value2
 key3:   value3
EOL

# Test Case 2: Excessive whitespace
cat <<extra_whitespace.yaml
key1:  value1
   
key2:
    value2
EOL

# Test Case 3: Missing newline at EOF
echo -n "key: value" > missing_newline.yaml

# Log the creation of smoke tests
echo "Smoke tests for yamlfmt created in $SMOKE_TEST_DIR"

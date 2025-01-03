#!/usr/bin/env bash
# Filename: create-smoke-tests.sh
# Description: Creates test cases to validate yamlfmt hook functionality.

# Define the directory to store test cases
SMOKE_TEST_DIR="$(dirname "${BASH_SOURCE[0]}")/smoke-tests"
mkdir -p "$SMOKE_TEST_DIR"

# Test Case 1: Unformatted YAML
cat > "$SMOKE_TEST_DIR/unformatted.yaml" <<EOFYAML
key1: value1
key2:value2
 key3:   value3
EOFYAML

# Test Case 2: Excessive whitespace
cat > "$SMOKE_TEST_DIR/extra_whitespace.yaml" <<EOFYAML
key1:  value1
   
key2:
    value2
EOFYAML

# Test Case 3: Missing newline at EOF
echo -n "key: value" > "$SMOKE_TEST_DIR/missing_newline.yaml"

# Log the creation of smoke tests
echo "Smoke tests for yamlfmt created in $SMOKE_TEST_DIR"
EOF

#!/usr/bin/env bash
# Filename: test/smoke-test/pre-commit-config/pre-commit-repo/create-smoke-tests.sh
# Description: Create smoke test files for the pre-commit-repo hooks

BASE_DIR="test/smoke-test/pre-commit-config/pre-commit-repo/smoke-tests"

# Ensure the directory exists
mkdir -p "$BASE_DIR"

cd "$BASE_DIR" || exit 1

echo "Creating smoke test files..."

test_content=(
    "This line has trailing spaces.
        Another bad line.   "
    "This file does not end with a newline."
)

# Create a large file to test check-added-large-files
head -c 6M </dev/urandom > large-file.bin
echo "Created large-file.bin"

# Create case-sensitive conflicting files to test check-case-conflict
touch caseSensitive.txt
touch casesensitive.txt
echo "Created caseSensitive.txt and casesensitive.txt"

# Create a file with trailing whitespace to test trailing-whitespace
cat <<EOL > trailing-whitespace.txt
This line has trailing spaces.
Another bad line.
EOL
echo "Created trailing-whitespace.txt"

# Create a file missing a newline at the end to test end-of-file-fixer
cat <<EOL > eof-missing-newline.txt
This file does not end with a newline.
EOL
echo "Created eof-missing-newline.txt"

# Create an invalid YAML file to test check-yaml
cat <<EOL > invalid.yaml
key: value
- invalid yaml structure
EOL
echo "Created invalid.yaml"

# Create an invalid TOML file to test check-toml
cat <<EOL > invalid.toml
[table
key = "value"
EOL
echo "Created invalid.toml"

# Create a Python file with debug statements to test debug-statements
cat <<EOL > debug.py
def test_function():
    print("Debugging with print statement")
    import pdb; pdb.set_trace()
EOL
echo "Created debug.py"

# Create a JSON file with single quotes to test double-quote-string-fixer
cat <<EOL > json-file.json
{
  'key': 'value'
}
EOL
echo "Created json-file.json"

# Create a Python test file with an invalid test name to test name-tests-test
cat <<EOL > test_example.py
def example_function():
    assert True
EOL
echo "Created test_example.py"

# Create a requirements.txt file with duplicate entries to test requirements-txt-fixer
cat <<EOL > requirements.txt
flask==2.1.2
Django==4.0
flask==2.1.2
EOL
echo "Created requirements.txt"

# Create a file with unresolved merge conflict markers to test check-merge-conflict
cat <<EOL > merge-conflict.txt
<<<<<<< HEAD
This is from the main branch.
=======
This is from the feature branch.
>>>>>>>
EOL
echo "Created merge-conflict.txt"

# Create a file with mixed line endings to test mixed-line-ending
printf "This line has LF endings.\nThis line has CRLF endings.\r\n" > mixed-line-endings.txt
echo "Created mixed-line-endings.txt"

echo "All smoke test files created in test/smoke-test/"

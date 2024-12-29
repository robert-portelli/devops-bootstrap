#!/usr/bin/env bash
# Filename: test/smoke-test/.github/workflows/super-linter/create-smoke-tests.bash
# Description: Script to create smoke test files for Super Linter.

# Ensure the directory exists
mkdir -p test/smoke-test/.github/workflows/super-linter
cd test/smoke-test/.github/workflows/super-linter || exit 1

# Create Bash Script smoke test
cat << EOL > script-issues.sh
#!/usr/bin/env bash
echo "Hello, World!"
echo "This line has trailing spaces.    "   
[ \$1 == "test" ] && echo "Equality operator should be '==' in double brackets."

# issues:
#    - trailing spaces on line 3
#    - Incorrect usage of == in a single-bracket test ([ \$1 == "test" ]).
EOL

# Create Shell Script smoke test
cat << EOL > shell-issues.sh
#!/bin/bash
if [ -z \$1 ]; then
    echo Usage: \$0 <arg>
fi
echo "Misaligned indentation on this line"

# issues:
#    - \$1 is not quoted in [ -z \$1 ].
#    - Missing double quotes around Usage: \$0 <arg>.
#    - Indentation is misaligned on the last echo statement.
EOL

# Create YAML file smoke test
cat << EOL > yaml-issues.yaml
name: Example Workflow
on: 
  push: null
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Lint this file!"  

# issues:
#    - null truthy value in push (not true or false).
#    - Trailing space at the end of the run line.
#    - Missing indentation consistency (e.g., jobs.example vs. jobs).
EOL

# Create Python Script smoke test
cat << EOL > python-issues.py
def greet(name:str)->str:
return f"Hello, {name}"

print(greet("World"))

# issues:
#    - Missing space after the : in name:str.
#    - Missing space before -> in ->str.
#    - Improper indentation on the return line.
#    - Unnecessary blank line before the print statement.
EOL

# Create Markdown file smoke test
cat << EOL > markdown-issues.md
# Example Project

This is a test markdown file
    - Indentation of bullet points is incorrect.
- No period at the end of the sentence

# issues:
#    - Missing punctuation in the first sentence of the second line.
#    - Improper indentation of bullet points.
EOL

# Create Git Merge Conflict Marker test
cat << EOL > conflict-markers.txt
<<<<<<< HEAD
This is conflicting text from the main branch.
=======
This is conflicting text from the feature branch.
>>>>>>>

# issues:
#    - Unresolved Git merge conflict markers (<<<<<<<, =======, >>>>>>>).
EOL

echo "Smoke test files created in $(pwd)"

#!/bin/bash
if [ -z $1 ]; then
    echo Usage: $0 <arg>
fi
echo "Misaligned indentation on this line"

# issues:
#    - $1 is not quoted in [ -z $1 ].
#    - Missing double quotes around Usage: $0 <arg>.
#    - Indentation is misaligned on the last echo statement.

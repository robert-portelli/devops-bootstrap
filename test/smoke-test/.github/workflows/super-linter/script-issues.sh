#!/usr/bin/env bash
echo "Hello, World!"
echo "This line has trailing spaces.    "   
[ $1 == "test" ] && echo "Equality operator should be '==' in double brackets."

# issues:
#    - trailing spaces on line 3
#    - Incorrect usage of == in a single-bracket test ([ $1 == "test" ]).

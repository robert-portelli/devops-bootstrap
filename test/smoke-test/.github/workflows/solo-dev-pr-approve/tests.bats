#!/usr/bin/env bash
# Filename: test/test_common_setup.bats
# Description:
# Usage: called by ./test_workflow.sh

function setup {
    load 'test_helpers/_common_setup'
    _common_setup
}

@test "test case 1a: always passes && bats-core working" {
    run true
    [[ "$status" -eq 0 ]]
}

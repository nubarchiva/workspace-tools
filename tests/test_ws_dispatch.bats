#!/usr/bin/env bats
# Tests para el despachador ws - Abreviaturas de comandos

load 'test_helper'

setup() {
    setup_test_environment
}

teardown() {
    teardown_test_environment
}

@test "ws: mg expands to mgmt-link" {
    run run_ws mg --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws mgmt-link"* ]]
}

@test "ws: d expands to doctor" {
    run run_ws d --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso: ws doctor"* ]]
}

@test "ws: m is ambiguous between mvn, mode and mgmt-link" {
    run run_ws m
    [ "$status" -ne 0 ]
    [[ "$output" == *"mgmt-link"* ]]
}

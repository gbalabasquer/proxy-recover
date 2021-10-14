#!/usr/bin/env bash
set -e

export DAPP_BUILD_OPTIMIZE=1
export DAPP_BUILD_OPTIMIZE_RUNS=200

export DAPP_TEST_ADDRESS=0xdB33dFD3D61308C33C63209845DaD3e6bfb2c674

if [[ -z "$1" ]]; then
    dapp --use solc:0.6.12 test -v
else
    dapp --use solc:0.6.12 test --match "$1" -vv
fi

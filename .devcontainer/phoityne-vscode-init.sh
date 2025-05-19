#!/bin/sh
GHCUP_BIN_DIR=$1
STACK_BIN_DIR=$2
export PATH=${GHCUP_BIN_DIR}:${STACK_BIN_DIR}:$PATH
stack install ghci-dap haskell-dap
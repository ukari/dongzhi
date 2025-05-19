#!/bin/sh
GHCUP_BIN_DIR=$1
HOOHLE_CACHE_DIR=$2
export PATH=${GHCUP_BIN_DIR}:$PATH
HOOGLE_ROOT=$(stack path --local-hoogle-root)
mkdir -p ${HOOGLE_ROOT}
touch ${HOOGLE_ROOT}/database.hoo
mv ${HOOHLE_CACHE_DIR}/* ${HOOGLE_ROOT}
stack hoogle -- generate
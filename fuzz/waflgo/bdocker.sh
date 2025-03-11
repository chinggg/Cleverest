#!/bin/bash

# build waflgo docker image for project
# usage: bdocker.sh <path-to-project-config> <commit>
set -e

SCENARIO=${SCENARIO:-BIC}
conf=${1-"jerryscript.env"}
source $conf

# if $commit is not set, build all commits
if [ -z "$2" ]; then
    for i in "${!COMMITS[@]}"; do
        commit=${COMMITS[$i]}
        docker build -t waflgo_$PROJ_NAME:$commit -f waflgo_$PROJ_NAME.Dockerfile --build-arg commit=$commit . --progress=plain 2>&1 | tee logs/bwaflgo_$commit.log
    done
    exit 0
fi

commit=$2
docker build -t waflgo_$PROJ_NAME:$commit -f waflgo_$PROJ_NAME.Dockerfile --build-arg commit=$commit . --progress=plain 2>&1 | tee logs/bwaflgo_$commit.log
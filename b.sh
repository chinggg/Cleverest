#!/bin/bash

# usage: b.sh <path-to-project-config> ...

SCENARIO=${SCENARIO:-BIC}
source $1
source utils.sh

[ -d $PROJ_NAME ] || clone_repo
pushd $PROJ_NAME
for i in "${!COMMITS[@]}"; do
    commit=${COMMITS[$i]}   
    builddir_before=build_before_$commit
    builddir_after=build_after_$commit
    buildafl_before=buildafl_before_$commit
    buildafl_after=buildafl_after_$commit

    # Build two versions of the program before and after the commit, if not exist
    if [ ! -d $builddir_before ]; then
        git checkout --force $commit^ || { echo "Failed to checkout commit_before $commit^, exiting."; exit 1;}
        (set -x; pre_build $builddir_before)
        build_target $builddir_before > build_before_$commit.log 2>&1 || echo "Build failed with code $?"
        (set -x; post_build $builddir_before)
    fi
    if [ ! -d $builddir_after ]; then
        git checkout --force $commit || { echo "Failed to checkout commit_after $commit, exiting."; exit 1;}
        (set -x; pre_build $builddir_after)
        build_target $builddir_after > build_after_$commit.log 2>&1 || echo "Build failed with code $?"
        (set -x; post_build $builddir_after)
    fi
    if [ ! -d $buildafl_before ]; then
        git checkout --force $commit^ || { echo "Failed to checkout commit_before $commit^, exiting."; exit 1;}
        (set -x; pre_build $buildafl_before)
        buildafl_target $buildafl_before > buildafl_before_$commit.log 2>&1 || echo "Build failed with code $?"
        (set -x; post_build $buildafl_before)
    fi
    if [ ! -d $buildafl_after ]; then
        git checkout --force $commit || { echo "Failed to checkout commit_after $commit, exiting."; exit 1;}
        (set -x; pre_build $buildafl_after)
        buildafl_target $buildafl_after > buildafl_after_$commit.log 2>&1 || echo "Build failed with code $?"
        (set -x; post_build $buildafl_after)
    fi
done

#!/bin/bash

get_cmd () {
    local cmd="$1"
    local input_file="$2"
    # replace @@ in cmd with input_file and execute
    echo "$cmd" | sed "s|@@|$input_file|g"  # use | because $input_file may contain /
}

check_output_invalid() {
    # if $1 contains $BASH_SOURCE, "No such", means execution is unusual and not valid
    if [[ "$1" == *"$BASH_SOURCE"* || "$1" == *"No such"* || "$1" == *"Usage"* || "$1" == *"Is a directory"* ]]; then
        return $(true)
    fi
    return $(false)
}

check_output_bug() {
    # check existence of bug, currently support parse specific kind of bug from AddressSanitizer output
    # example input: multi-line string containing "ERROR: AddressSanitizer: global-buffer-overflow"
    # should return: "global-buffer-overflow"
    # find lines containing "ERROR: AddressSanitizer" and extract the bug type after ": "
    echo "$1" | grep -oP "ERROR: AddressSanitizer: \K[a-zA-Z-]+" | head -1
}

parse_llm_input() {
    local ans=$1
    local input=$(echo "$ans" | sed -n '/^```/,/^```/ p' | sed '1d;$d')
    echo "$input"
}

parse_llm_cmd() {
    local ans=$1
    local cmd=$(echo "$ans" | sed -n 's/Command: `\([^`]*\)`/\1/p')
    echo "$cmd"
}

# if cmd contain 'rm' or 'sudo', complain and abort
abort_if_cmd_danger() {
    local cmd=$1
    if [[ $cmd =~ "rm" ]] || [[ $cmd =~ "sudo" ]]; then
        echo "Command $cmd contains dangerous operation, aborting."
        exit 1
    fi
}

commit_affected_lines() {
    local commit=$1
    local file=$2
    local lines_before=()
    local lines_after=()

    local diff_output=$(git diff -U0 ${commit}^ ${commit} -- $file)

    echo "$diff_output" | gawk '
        BEGIN {
            PROCINFO["sorted_in"]="@ind_num_asc"
            # Initialize arrays to avoid undefined errors
            split("", lines_before);
            split("", lines_after);
        }
        /^\@\@/ {
            split($0, parts, " ");
            split(parts[2], range_before, ",");
            split(parts[3], range_after, ",");
            
            # Remove "+" or "-" from start
            sub(/^[-+]/, "", range_before[1]);
            sub(/^[-+]/, "", range_after[1]);
            
            # Calculate line ranges and populate arrays
            start_before = range_before[1];
            num_lines_before = range_before[2] == "" ? 1 : range_before[2];
            start_after = range_after[1];
            num_lines_after = range_after[2] == "" ? 1 : range_after[2];
            
            for (i = 0; i < num_lines_before; i++) {
                lines_before[start_before + i] = 1; # Use associative array to avoid duplicates
            }
            for (i = 0; i < num_lines_after; i++) {
                lines_after[start_after + i] = 1;
            }
        }
        END {
            # Print lines_before and lines_after without duplicates
            printf "lines_before:";
            for (line in lines_before) {
                printf "%s,", line;
            }
            printf "\nlines_after:";
            for (line in lines_after) {
                printf "%s,", line;
            }
            printf "\n";
        }
    ' | sed 's/,\n/\n/g'
}

git_commit_content() {
    local commit=$1
    git show --format=%B $commit
}

git_commit_msgonly() {
    local commit=$1
    git show -s --format=%B $commit
}

git_commit_diffonly() {
    local commit=$1
    git diff ${commit}^ ${commit}
}

is_commit_codechange() {
# return $(true) if commit change *.c *.cpp file, $(false) otherwise
    local commit=$1
    git diff --name-only HEAD^ HEAD | grep -E "\.(c|cpp)$"
}

commit_oneline() {
# [githash] # one-line commit message
    local commit=$1
    git show -s --format="%h # %s" --abbrev=7 $commit
}

recent_codechange_commits() {
    local n=$1
    local count=0
    git log --format="%h" | while read commit; do
        if git show --name-only "$commit" | grep -E '\.(c|cc|cpp)$' > /dev/null; then
            if ! git log -1 --format="%s" "$commit" | grep -qE "doc:|build:|windows:"; then
                git log -1 --format="%h # %s" "$commit"
                count=$((count + 1))
                if [ $count -ge $n ]; then
                    break
                fi
            fi
        fi
    done
}

afl_testcase_ms() {
    # example input from AFL++: fuzzout_8c27b12_after/default/crashes/id:000005,sig:06,src:002721+000002,time:40439616,execs:2445419,op:splice,rep:1
    # example input from WAFLGO: out_mujs_4c7f6be_1/crashes/target_id:000000,1197472,sig:11,src:000524,op:havoc,rep:4
    # should return time in milliseconds
    local testcase=$1
    time=$(echo "$testcase" | grep -oP "time:\K[0-9]+" | awk '{print $1}')
    # if time is empty, try WAFLGo pattern, parse second column split by comma
    [ -z "$time" ] && time=$(echo "$testcase" | awk -F, '{print $2}')
    echo "$time"
}

repeat() {
# usgae: repeat <n> <command>
    # if $1 is number, n=$1 and shift, otherwise n=1
    if [[ $1 =~ ^[0-9]+$ ]]; then
        n=$1
        shift
    else
        n=1
    fi
    for i in $(seq $n); do
        $@
    done
}
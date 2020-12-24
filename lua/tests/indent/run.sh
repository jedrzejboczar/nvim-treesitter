#!/usr/bin/env bash

HERE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

repo_root="$HERE/../../../"
minimal_init="$repo_root/scripts/minimal_init.vim"
setup_lua="$HERE/setup.lua"
work_dir="/tmp/nvim-treesitter-test"

run_nvim() {
    # pass root directory as environmental variable, which is then used
    # to the nvim-treesitter plugin, then initialize nvim-treesitter indent
    ROOT="$repo_root" nvim --noplugin -u "$minimal_init" -c "luafile $setup_lua" "$@"
}

indent() {
    file="$1"
    run_nvim --headless "$file" -c "normal gg=G" -c "write" -c "quit"
}

copy() {
    ref_file="$1"
    work_file="$2"
    mkdir -p "$(dirname "$work_file")"
    cp "$ref_file" "$work_file"
}

base_path() {
    path="$1"
    echo "${path#$HERE}"
}

test_file() {
    ref_file="$1"
    work_file="$2"
    diff_file="${work_file}.diff"
    copy "$ref_file" "$work_file"
    indent "$work_file"
    diff "$ref_file" "$work_file" > "$diff_file"
}

run_test() {
    ref_file="$1"
    name="$(base_path "$ref_file")"
    work_file="$work_dir/$name"
    stdout_file="${work_file}.stdout"
    stderr_file="${work_file}.stderr"
    echo -n "  Testing ${name#/} ... "
    test_file "$ref_file" "$work_file" > "$stdout_file" 2> "$stderr_file" \
        && echo "OK" || echo "ERROR"
}

echo "Running tests"
echo

for filetype in $HERE/*/; do
    ft="${filetype#$HERE/}"
    echo "Filetype: ${ft%/}"
    for test_file in $filetype/*; do
        run_test $test_file
    done
done

echo
echo "Test results in:"
echo "  $work_dir"

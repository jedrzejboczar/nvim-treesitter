#!/usr/bin/env bash

HERE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd $HERE/..

run() {
    nvim --headless --noplugin -u scripts/minimal_init.lua \
        -c "PlenaryBustedDirectory $1 { minimal_init = './scripts/minimal_init.lua' }"
}

if [[ $1 = '--summary' ]]; then
    # really simple results summary by filtering plenary busted output
    run tests/indent/ 2> /dev/null | grep -E '^\S*(Success|Fail(ed)?|Errors?)'
elif [[ $1 = '--totals' ]]; then
    # use sed to remove color codes for easier parsing
    remove_color_codes='s/\x1B\[[0-9;]\{1,\}[A-Za-z]//g'
    # use awk to get total counts
    read -r -d '' awk_prog << EOF
BEGIN { FS = ": "}
/^[^|]+:/ {
    class = gsub(/[[:space:]]*/, "", \$1)
    if (match(\$1, /^(Success|Failed|Errors)/))
        counts[\$1] += \$2
}
END {
    for (word in counts)
        total += counts[word]
    for (word in counts)
        printf "%s: %d (%.1f%%)\n", word, counts[word], counts[word] / total * 100
}
EOF
    run tests/indent/ 2> /dev/null \
        | sed "$remove_color_codes" \
        | awk "$awk_prog"
elif [[ $1 = '--unit' ]]; then
    run tests/unit
else
    run tests/indent/
fi

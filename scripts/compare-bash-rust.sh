#!/usr/bin/env bash
#
# Compare the Bash and Rust implementations of `gt`.
# Runs identical commands against both binaries in isolated temp directories
# and reports differences in exit codes, stdout, stderr, and generated files.
#
# Known expected differences that are NORMALIZED:
#   - Version strings: "v1.7.0-SNAPSHOT" (Bash) vs "v1.7.0-SNAPSHOT-rust" (Rust)
#   - Script name in version line: "gt.sh" / "gt-remote.sh" etc. vs "gt"
#   - Absolute temp paths: /tmp/.../bash/ vs /tmp/.../rust/ (replaced with /TMPDIR/)
#   - Bash prints call stack (traceAndDie) which Rust doesn't reproduce
#
# Usage:
#   ./scripts/compare-bash-rust.sh [test-filter]
#

set -euo pipefail
shopt -s inherit_errexit || { echo >&2 "requires bash 5"; exit 1; }

readonly GT_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly GT_BASH="${GT_REPO}/src/gt.sh"
readonly GT_RUST_BUILD_DIR="${GT_REPO}/rust"
readonly GT_RUST="${GT_RUST_BUILD_DIR}/target/release/gt"

readonly C_OK="\x1b[0;32m"
readonly C_DIFF="\x1b[0;31m"
readonly C_WARN="\x1b[0;93m"
readonly C_INFO="\x1b[0;34m"
readonly C_RESET="\x1b[0m"

declare -i TOTAL=0 PASSED=0 FAILED=0 WARN=0

# ---------------------------------------------------------------------------
# build rust binary if needed
# ---------------------------------------------------------------------------
build_rust() {
    if [[ ! -x $GT_RUST ]]; then
        echo -e "${C_INFO}INFO${C_RESET}: building Rust binary..."
        (cd "$GT_RUST_BUILD_DIR" && cargo build --release)
    fi
}

# ---------------------------------------------------------------------------
# normalization helpers
# ---------------------------------------------------------------------------
normalize() {
    sed \
        -e 's/v1\.7\.0-SNAPSHOT-rust/v1.7.0-SNAPSHOT/g' \
        -e 's/Version of gt\.sh is:/Version of gt is:/g' \
        -e 's/Version of gt-remote\.sh is:/Version of gt is:/g' \
        -e 's/Version of gt-self-update\.sh is:/Version of gt is:/g' \
        -e 's/Version of parse-commands\.sh is:/Version of gt is:/g' \
        -e 's/Version of gt-update\.sh is:/Version of gt is:/g' \
        -e 's/Version of gt-pull\.sh is:/Version of gt is:/g' \
        -e 's/Version of gt-re-pull\.sh is:/Version of gt is:/g' \
        -e 's/Version of gt-reset\.sh is:/Version of gt is:/g' \
        -e 's/ERROR: no command passed to gt\.sh/ERROR: no command passed to gt/g' \
        < "$1"
}

normalize_temp_paths() {
    sed \
        -e 's|/tmp/gt-compare-[^/]*/bash|/TMPDIR|g' \
        -e 's|/tmp/gt-compare-[^/]*/rust|/TMPDIR|g' \
        -e 's|/tmp/gt-install-[^/]*/gpg|/TMPDIR/gpg|g' \
        -e 's|/tmp/gt-install-[^/]*/repo|/TMPDIR/repo|g'
}

strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# ---------------------------------------------------------------------------
# run helpers
# ---------------------------------------------------------------------------
unique_base() {
    mktemp -d -t gt-compare-XXXXXXXXXX
}

run_bash() {
    local dir=$1 cmd=$2 stdin=$3
    cd "$dir"
    if [[ -n ${stdin:-} ]]; then
        # shellcheck disable=SC2086
        bash "$GT_BASH" $cmd < <(printf '%s' "$stdin") >bash.stdout 2>bash.stderr || true
    else
        # shellcheck disable=SC2086
        bash "$GT_BASH" $cmd >bash.stdout 2>bash.stderr || true
    fi
    printf '%s\n' "${PIPESTATUS[0]}" >bash.exit
}

run_rust() {
    local dir=$1 cmd=$2 stdin=$3
    cd "$dir"
    if [[ -n ${stdin:-} ]]; then
        # shellcheck disable=SC2086
        printf '%s' "$stdin" | "$GT_RUST" $cmd >rust.stdout 2>rust.stderr || true
    else
        # shellcheck disable=SC2086
        "$GT_RUST" $cmd >rust.stdout 2>rust.stderr || true
    fi
    printf '%s\n' "${PIPESTATUS[0]}" >rust.exit
}

# ---------------------------------------------------------------------------
# comparison core
# ---------------------------------------------------------------------------
compare_and_report() {
    local test_name=$1 base=$2 bash_dir=$3 rust_dir=$4
    local bash_exit rust_exit
    bash_exit=$(cat "$bash_dir/bash.exit" 2>/dev/null || echo "?")
    rust_exit=$(cat "$rust_dir/rust.exit" 2>/dev/null || echo "?")

    local ok=true
    echo -n "[$TOTAL] $test_name ... "

    # Compare exit codes
    if [[ $bash_exit != "$rust_exit" ]]; then
        echo ""
        echo -e "  ${C_DIFF}  exit code: bash=${bash_exit} vs rust=${rust_exit}${C_RESET}"
        ok=false
    fi

    # Normalize outputs
    normalize "$bash_dir/bash.stdout" | normalize_temp_paths >"$base/bash.stdout.norm"
    normalize "$rust_dir/rust.stdout" | normalize_temp_paths >"$base/rust.stdout.norm"
    normalize "$bash_dir/bash.stderr" | normalize_temp_paths >"$base/bash.stderr.norm"
    normalize "$rust_dir/rust.stderr" | normalize_temp_paths >"$base/rust.stderr.norm"

    strip_ansi < "$base/bash.stdout.norm" >"$base/bash.stdout.clean"
    strip_ansi < "$base/rust.stdout.norm" >"$base/rust.stdout.clean"
    strip_ansi < "$base/bash.stderr.norm" >"$base/bash.stderr.clean"
    strip_ansi < "$base/rust.stderr.norm" >"$base/rust.stderr.clean"

    # Bash prints help to stderr on error; Rust prints help to stdout.
    # Merge both streams and compare combined content.
    cat "$base/bash.stdout.clean" "$base/bash.stderr.clean" | sort >"$base/bash.combined"
    cat "$base/rust.stdout.clean" "$base/rust.stderr.clean" | sort >"$base/rust.combined"

    if ! diff -q "$base/bash.combined" "$base/rust.combined" >/dev/null 2>&1; then
        if $ok; then echo ""; fi
        echo -e "  ${C_DIFF}  combined stdout+stderr content differs${C_RESET}"
        diff --color=always -u "$base/bash.combined" "$base/rust.combined" 2>/dev/null | head -20 || true
        ok=false
    fi

    # Compare generated file trees
    if [[ -d "$bash_dir/.gt" ]] && [[ -d "$rust_dir/.gt" ]]; then
        find "$bash_dir/.gt" -name 'pull.args' -exec sed -i 's/v1\.7\.0-SNAPSHOT/v1.7.0-SNAPSHOT-rust/g' {} \;
        if ! diff -ru "$bash_dir/.gt" "$rust_dir/.gt" >/dev/null 2>&1; then
            if $ok; then echo ""; fi
            echo -e "  ${C_DIFF}  .gt/ file tree differs${C_RESET}"
            diff -ru "$bash_dir/.gt" "$rust_dir/.gt" 2>/dev/null | head -30 || true
            ok=false
        fi
    fi

    if $ok; then
        echo -e "${C_OK}PASS${C_RESET}"
        ((++PASSED))
    else
        echo -e "  ${C_DIFF}FAIL${C_RESET}"
        ((++FAILED))
    fi

    rm -rf "$base"
}

# ---------------------------------------------------------------------------
# test wrappers
# ---------------------------------------------------------------------------
cmp_test() {
    local test_name=$1
    ((++TOTAL))
    if [[ -n ${TEST_FILTER:-} ]] && [[ $test_name != *"$TEST_FILTER"* ]]; then
        ((--TOTAL))
        return
    fi

    local base bash_dir rust_dir
    base=$(unique_base)
    bash_dir="$base/bash" rust_dir="$base/rust"
    mkdir -p "$bash_dir" "$rust_dir"

    (cd "$bash_dir" && run_bash "$bash_dir" "$2" "${3:-}")
    (cd "$rust_dir" && run_rust "$rust_dir" "$2" "${3:-}")

    compare_and_report "$test_name" "$base" "$bash_dir" "$rust_dir"
}

cmp_test_with_setup() {
    local test_name=$1 cmd=$2 stdin=${3:-} setup=${4:-}
    ((++TOTAL))
    if [[ -n ${TEST_FILTER:-} ]] && [[ $test_name != *"$TEST_FILTER"* ]]; then
        ((--TOTAL))
        return
    fi

    local base bash_dir rust_dir
    base=$(unique_base)
    bash_dir="$base/bash" rust_dir="$base/rust"
    mkdir -p "$bash_dir" "$rust_dir"

    if [[ -n $setup ]]; then
        (cd "$bash_dir" && eval "$setup")
        (cd "$rust_dir" && eval "$setup")
    fi

    (cd "$bash_dir" && run_bash "$bash_dir" "$cmd" "$stdin")
    (cd "$rust_dir" && run_rust "$rust_dir" "$cmd" "$stdin")

    compare_and_report "$test_name" "$base" "$bash_dir" "$rust_dir"
}

# ---------------------------------------------------------------------------
# main test suite
# ---------------------------------------------------------------------------
main() {
    TEST_FILTER="${1:-}"

    build_rust

    echo "=================================="
    echo "Comparing Bash vs Rust gt"
    echo "Repo: ${GT_REPO}"
    echo "Bash: ${GT_BASH}"
    echo "Rust: ${GT_RUST}"
    echo "Filter: ${TEST_FILTER:-(none)}"
    echo "=================================="

    echo ""
    echo "--- Phase 1: CLI Surface ---"
    cmp_test "1. gt --version" "--version"
    cmp_test "2. gt --help" "--help"
    cmp_test "3. gt remote --help" "remote --help"
    cmp_test "4. gt remote add --help" "remote add --help"
    cmp_test "5. gt remote remove --help" "remote remove --help"
    cmp_test "6. gt remote list --help" "remote list --help"
    cmp_test "7. gt self-update --help" "self-update --help"
    cmp_test "8. gt self-update --version" "self-update --version"
    cmp_test "9. gt unknown" "unknown"
    cmp_test "10. gt remote unknown" "remote unknown"
    cmp_test "11. gt (no args)" ""

    echo ""
    echo "--- Phase 2: remote add ---"
    cmp_test_with_setup "12. add invalid name" \
        "remote add -r 'bad name' -u http://x" \
        "" \
        'mkdir -p .gt'

    cmp_test_with_setup "13. add missing args" \
        "remote add" \
        "" \
        'mkdir -p .gt'

    cmp_test_with_setup "14. add working dir outside" \
        "remote add -r test -u http://x -w .." \
        "" \
        'mkdir -p .gt'

    cmp_test_with_setup "15. list wd outside" \
        "remote list -w .." \
        "" \
        'mkdir -p .gt'

    echo ""
    echo "--- Phase 3: remote list ---"
    cmp_test_with_setup "16. list empty" \
        "remote list" \
        "" \
        'mkdir -p .gt'

    cmp_test_with_setup "17. list non-empty" \
        "remote list" \
        "" \
        'mkdir -p .gt/remotes/alpha .gt/remotes/zeta'

    echo ""
    echo "--- Phase 4: remote remove ---"
    cmp_test_with_setup "18. remove simple" \
        "remote remove -r gone" \
        "" \
        'mkdir -p .gt/remotes/gone/public-keys; touch .gt/remotes/gone/pull.args'

    cmp_test_with_setup "19. remove missing" \
        "remote remove -r nope" \
        "" \
        'mkdir -p .gt/remotes/other'

    echo ""
    echo "--- Phase 5: unported (expected differences) ---"
    echo "      NOTE: These are expected to differ. Bash validates .gt first;"
    echo "      Rust rejects immediately at the top level."
    cmp_test "20. unported pull" "pull"
    cmp_test "21. unported re-pull" "re-pull"
    cmp_test "22. unported reset" "reset"
    cmp_test "23. unported update" "update"

    echo ""
    echo "--- Phase 6: self-update ---"
    echo "      NOTE: Bash self-update may download from GitHub"
    echo "      when run from the repo itself. Reported as known gap."
    cmp_test "24. self-update corrupt" "self-update"

    echo ""
    echo "=================================="
    echo "Results: $PASSED/$TOTAL passed, $FAILED failed, $WARN warnings"
    echo "=================================="

    if ((FAILED > 0)); then
        exit 1
    fi
}

main "$@"

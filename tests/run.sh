#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
CLI="$ROOT_DIR/clipcopy"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

pass_count=0
fail_count=0

assert_eq() {
  expected=$1
  actual=$2
  message=$3
  if [ "$expected" != "$actual" ]; then
    echo "FAIL: $message" >&2
    echo "  expected: $(printf '%s' "$expected" | cat -v)" >&2
    echo "  actual:   $(printf '%s' "$actual" | cat -v)" >&2
    fail_count=$((fail_count + 1))
    return 1
  fi
  pass_count=$((pass_count + 1))
}

assert_contains() {
  needle=$1
  haystack=$2
  message=$3
  case "$haystack" in
    *"$needle"*) pass_count=$((pass_count + 1)) ;;
    *)
      echo "FAIL: $message" >&2
      echo "  missing: $needle" >&2
      echo "  got:     $haystack" >&2
      fail_count=$((fail_count + 1))
      return 1
      ;;
  esac
}

# Read clipboard file raw, preserving trailing newlines via sentinel
clip_raw() {
  raw=$(cat "$TEST_CLIP_FILE"; printf x)
  printf '%s' "${raw%x}"
}

# Assert that the raw clipboard file content matches expected bytes exactly
assert_clip_eq() {
  expected=$1
  message=$2
  expected_file="$TMP_DIR/expected.bin"
  printf '%s' "$expected" > "$expected_file"
  if ! cmp -s "$expected_file" "$TEST_CLIP_FILE"; then
    echo "FAIL: $message" >&2
    echo "  expected: $(cat -v "$expected_file")" >&2
    echo "  actual:   $(cat -v "$TEST_CLIP_FILE")" >&2
    fail_count=$((fail_count + 1))
    return 1
  fi
  pass_count=$((pass_count + 1))
}

# Stub pbcopy so tests do not touch system clipboard.
cat > "$TMP_DIR/pbcopy" <<'STUB'
#!/usr/bin/env sh
cat > "$TEST_CLIP_FILE"
STUB
chmod +x "$TMP_DIR/pbcopy"

export PATH="$TMP_DIR:$PATH"
export TEST_CLIP_FILE="$TMP_DIR/clipboard.txt"

# ===== Positional arguments =====

"$CLI" "hello"
assert_clip_eq "hello" "copies single positional arg"

"$CLI" "hello" "world"
assert_clip_eq "hello world" "copies multiple positional args joined by space"

"$CLI" "a" "b" "c" "d"
assert_clip_eq "a b c d" "copies many positional args"

"$CLI" "  spaces  inside  "
assert_clip_eq "  spaces  inside  " "preserves spaces within a single arg"

# ===== Stdin =====

printf 'from stdin' | "$CLI"
assert_clip_eq "from stdin" "copies stdin text"

printf 'line1\nline2\nline3' | "$CLI"
assert_clip_eq "line1
line2
line3" "copies multiline stdin"

printf 'trailing newline\n' | "$CLI"
assert_clip_eq "trailing newline
" "preserves single trailing newline from stdin"

printf 'two newlines\n\n' | "$CLI"
assert_clip_eq "two newlines

" "preserves multiple trailing newlines from stdin"

printf '   leading and trailing spaces   ' | "$CLI"
assert_clip_eq "   leading and trailing spaces   " "preserves whitespace from stdin"

printf '\ttabs\tand\tspaces ' | "$CLI"
assert_clip_eq "	tabs	and	spaces " "preserves tabs from stdin"

printf 'special chars: !@#$%%^&*()' | "$CLI"
assert_clip_eq 'special chars: !@#$%^&*()' "copies special characters from stdin"

printf "single quote ' and double quote \"" | "$CLI"
assert_clip_eq "single quote ' and double quote \"" "copies quotes from stdin"

printf 'backslash \\ here' | "$CLI"
assert_clip_eq 'backslash \ here' "copies backslashes from stdin"

# ===== --print / -p flag =====

printed_output=$("$CLI" --print "done")
assert_clip_eq "done" "copies with --print"
assert_eq "done" "$printed_output" "prints with --print"

printed_output=$("$CLI" -p "short flag")
assert_clip_eq "short flag" "copies with -p"
assert_eq "short flag" "$printed_output" "prints with -p"

printed_output=$("$CLI" --print "multi" "word" "args")
assert_eq "multi word args" "$printed_output" "prints multiple args with --print"

printed_output=$(printf 'piped text' | "$CLI" -p)
assert_eq "piped text" "$printed_output" "prints piped stdin with -p"

# --print outputs exactly what was copied (no extra newline added)
print_out_file="$TMP_DIR/print_out.bin"
printf 'with newline\n' | "$CLI" -p > "$print_out_file"
expected_print="$TMP_DIR/expected_print.bin"
printf 'with newline\n' > "$expected_print"
if cmp -s "$expected_print" "$print_out_file"; then
  pass_count=$((pass_count + 1))
else
  echo "FAIL: --print outputs exact copied bytes (no extra newline)" >&2
  echo "  expected: $(cat -v "$expected_print")" >&2
  echo "  actual:   $(cat -v "$print_out_file")" >&2
  fail_count=$((fail_count + 1))
fi

# --print without text should still fail
set +e
"$CLI" --print 2>/dev/null </dev/null
no_print_status=$?
set -e
assert_eq "1" "$no_print_status" "fails with --print but no input"

# ===== --help / -h =====

help_output=$("$CLI" --help)
assert_contains "Usage: clipcopy" "$help_output" "shows help with --help"
assert_contains "-p, --print" "$help_output" "help shows -p flag"
assert_contains "-h, --help" "$help_output" "help shows -h flag"

help_output=$("$CLI" -h)
assert_contains "Usage: clipcopy" "$help_output" "shows help with -h"

# help exits 0
set +e
"$CLI" --help >/dev/null 2>&1
help_status=$?
set -e
assert_eq "0" "$help_status" "--help exits 0"

# ===== Error cases =====

# no input
set +e
no_input_output=$("$CLI" 2>&1 </dev/null)
no_input_status=$?
set -e
assert_eq "1" "$no_input_status" "fails when no input"
assert_contains "No input provided" "$no_input_output" "shows no-input message"

# empty stdin
set +e
empty_stdin_output=$(printf '' | "$CLI" 2>&1)
empty_stdin_status=$?
set -e
assert_eq "1" "$empty_stdin_status" "fails on empty stdin"
assert_contains "No input provided" "$empty_stdin_output" "shows no-input message for empty stdin"

# unknown long flag
set +e
bad_flag_output=$("$CLI" --unknown 2>&1)
bad_flag_status=$?
set -e
assert_eq "1" "$bad_flag_status" "fails on unknown long flag"
assert_contains "Unknown flag" "$bad_flag_output" "shows unknown flag message"
assert_contains "--unknown" "$bad_flag_output" "shows the offending flag name"

# unknown short flag
set +e
bad_short_output=$("$CLI" -z 2>&1)
bad_short_status=$?
set -e
assert_eq "1" "$bad_short_status" "fails on unknown short flag"
assert_contains "Unknown flag" "$bad_short_output" "shows unknown flag message for short flag"

# ===== -- end-of-options =====

"$CLI" -- "-starts-with-dash"
assert_clip_eq "-starts-with-dash" "-- stops flag parsing for single dash"

"$CLI" -- "--looks-like-flag"
assert_clip_eq "--looks-like-flag" "-- allows double-dash text"

"$CLI" -- "-p"
assert_clip_eq "-p" "-- prevents -p from being parsed as flag"

"$CLI" -- "-h"
assert_clip_eq "-h" "-- prevents -h from being parsed as flag"

printed_output=$("$CLI" -p -- "--fake-flag")
assert_eq "--fake-flag" "$printed_output" "-p works before -- separator"

"$CLI" -- "a" "b" "c"
assert_clip_eq "a b c" "-- with multiple positional args"

# ===== Flag ordering =====

"$CLI" "text" "-p" 2>/dev/null || true
# -p after positional is treated as positional arg (break on *)
assert_clip_eq "text -p" "flag after positional is treated as text"

# ===== No clipboard backend =====

# Shadow all clipboard backends with stubs that exit 1
no_clip_dir="$TMP_DIR/no_clip"
mkdir -p "$no_clip_dir"
for cmd in pbcopy wl-copy xclip xsel; do
  printf '#!/usr/bin/env sh\nexit 1\n' > "$no_clip_dir/$cmd"
  chmod +x "$no_clip_dir/$cmd"
done
set +e
no_clip_output=$(PATH="$no_clip_dir:/usr/bin:/bin" "$CLI" "test" 2>&1)
no_clip_status=$?
set -e
assert_eq "1" "$no_clip_status" "fails when no clipboard backend"
assert_contains "No clipboard command found" "$no_clip_output" "shows missing backend message"
assert_contains "Install a clipboard utility" "$no_clip_output" "shows install hint"

# ===== Summary =====

echo ""
if [ "$fail_count" -gt 0 ]; then
  echo "$pass_count passed, $fail_count failed"
  exit 1
else
  echo "All $pass_count tests passed"
fi

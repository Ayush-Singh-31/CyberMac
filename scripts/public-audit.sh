#!/usr/bin/env bash
set -euo pipefail

failures=0

section() {
  printf '\n== %s ==\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

run_required() {
  section "$1"
  shift
  "$@" || fail "$1 failed"
}

section "swift test"
swift test

section "swift build"
swift build

section "git diff --check"
git diff --check

section ".DS_Store"
ds_store_matches="$(find . -name ".DS_Store" -print)"
if [[ -n "$ds_store_matches" ]]; then
  printf '%s\n' "$ds_store_matches"
  fail ".DS_Store files found"
fi

section "forbidden local/private paths"
private_matches="$(
  grep -RInE '/Users/ayush|sayush5191' . \
    --exclude-dir=.git \
    --exclude-dir=.build \
    --exclude-dir=.swiftpm \
    --exclude-dir=dist \
    --exclude-dir=release \
    --exclude='public-audit.sh' || true
)"
if [[ -n "$private_matches" ]]; then
  printf '%s\n' "$private_matches"
  fail "private path or identifier matches found"
fi

section "forbidden generated/runtime/mod artifacts"
artifact_matches="$(
  find . \
    \( -path './.git' -o -path './.build' -o -path './.swiftpm' \) -prune -o \
    \( \
      -name '.DS_Store' \
      -o -name 'redscript*' \
      -o -name 'input-loader*' \
      -o -name 'final.redscripts' \
      -o -name '*.redscripts' \
      -o -name '*.reds.cache' \
      -o -name '*.ts' \
      -o -name '*.bk' \
      -o -name '*.xlsx' \
      -o -name '*.xls' \
      -o -name '*.csv' \
      -o -name '*.archive' \
      -o -name '*.xl' \
      -o -name '*.tweak' \
      -o -name '*.reds.bak.*' \
      -o -name '*.backup' \
      -o -name '*.log' \
      -o -name '*.tmp' \
      -o -name '*.dmg' \
      -o -name '*.zip' \
    \) -print
)"
if [[ -n "$artifact_matches" ]]; then
  printf '%s\n' "$artifact_matches"
  fail "forbidden generated/runtime/mod artifacts found"
fi

section "CyberMacApp forbidden execution patterns"
app_matches="$(
  grep -RInE 'Process[[:space:]]*\(|/bin/(sh|zsh|bash)|(^|[^[:alnum:]_])(sh|zsh|bash)[[:space:]]+-c([^[:alnum:]_]|$)|osascript|with administrator privileges|AuthorizationExecuteWithPrivileges|NSAppleScript|do shell script' CyberMacApp --include='*.swift' || true
)"
if [[ -n "$app_matches" ]]; then
  printf '%s\n' "$app_matches"
  fail "forbidden app execution pattern found"
fi

section "CyberMacApp sudo review"
sudo_matches="$(grep -RIn 'sudo' CyberMacApp --include='*.swift' || true)"
if [[ -n "$sudo_matches" ]]; then
  printf '%s\n' "$sudo_matches"
  unexpected_sudo="$(
    printf '%s\n' "$sudo_matches" | grep -Ev 'CyberMacApp/AppState.swift:.*(sudoCommand|sudoCommands|printed sudo copy command)' || true
  )"
  if [[ -n "$unexpected_sudo" ]]; then
    fail "unexpected sudo reference in CyberMacApp"
  fi
  sudo_cp_matches="$(printf '%s\n' "$sudo_matches" | grep 'sudo cp' || true)"
  if [[ -n "$sudo_cp_matches" ]]; then
    fail "literal sudo cp found in CyberMacApp"
  fi
else
  printf 'No sudo references in CyberMacApp.\n'
fi

section "Core/CLI sudo command generation review"
core_sudo_cp_matches="$(grep -RIn 'sudo cp' Sources Tests --include='*.swift' || true)"
if [[ -n "$core_sudo_cp_matches" ]]; then
  printf '%s\n' "$core_sudo_cp_matches"
  printf 'Review: sudo cp appears outside CyberMacApp only as CLI/core command-generation or tests.\n'
else
  printf 'No sudo cp command-generation matches found outside CyberMacApp.\n'
fi

if [[ "$failures" -ne 0 ]]; then
  printf '\nPublic audit failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf '\nPublic audit passed.\n'

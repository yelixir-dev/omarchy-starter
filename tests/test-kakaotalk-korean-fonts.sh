#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PATCHER="$ROOT_DIR/patch-kakaotalk-korean-input.sh"
readonly INSTALLER="$ROOT_DIR/install-kakaotalk-bottles.sh"
readonly TMP_ROOT="$(mktemp -d)"
readonly TEST_HOME="$TMP_ROOT/home"
readonly FONT_SOURCE="$TMP_ROOT/fonts"
readonly FAKE_BIN="$TMP_ROOT/bin"
readonly FLATPAK_LOG="$TMP_ROOT/flatpak.log"
readonly DRIVE_C="$TEST_HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/kakaotalk/drive_c"
export FLATPAK_LOG

cleanup() {
  rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$*"
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq -- "$needle" "$file" || fail "$message (missing: <$needle>)"
}

[[ -x "$PATCHER" ]] || fail "patch script is absent or not executable"

mkdir -p -- "$TEST_HOME" "$FONT_SOURCE" "$FAKE_BIN" "$DRIVE_C/windows/Fonts"
printf 'batang fixture\n' >"$FONT_SOURCE/batang.ttf"
printf 'dotum fixture\n' >"$FONT_SOURCE/dotum.ttf"
printf 'gulim fixture\n' >"$FONT_SOURCE/gulim.ttf"

cat >"$FAKE_BIN/pacman" <<'PACMAN'
#!/usr/bin/env bash
[[ "${1:-}" == "-Q" && "${2:-}" == "ttf-baekmuk" ]]
PACMAN

cat >"$FAKE_BIN/flatpak" <<'FLATPAK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FLATPAK_LOG"

if [[ "${1:-}" == "info" ]]; then
  exit 0
fi

if [[ "${1:-}" == "run" && "${2:-}" == "--command=bottles-cli" ]]; then
  exit 0
fi

exit 64
FLATPAK
chmod +x -- "$FAKE_BIN/pacman" "$FAKE_BIN/flatpak"

run_patcher() {
  HOME="$TEST_HOME" \
    PATH="$FAKE_BIN:$PATH" \
    KAKAOTALK_FONT_SOURCE_DIR="$FONT_SOURCE" \
    "$PATCHER"
}

run_patcher >/dev/null || fail "patch script failed in sandbox"

cmp -s "$FONT_SOURCE/batang.ttf" "$DRIVE_C/windows/Fonts/batang.ttf" ||
  fail "Batang TTF was not copied"
cmp -s "$FONT_SOURCE/dotum.ttf" "$DRIVE_C/windows/Fonts/dotum.ttf" ||
  fail "Dotum TTF was not copied"
cmp -s "$FONT_SOURCE/gulim.ttf" "$DRIVE_C/windows/Fonts/gulim.ttf" ||
  fail "Gulim TTF was not copied"
pass "copies real Korean TTF files into the bottle"

assert_file_contains "$DRIVE_C/fix-korean-input.reg" \
  '"Baekmuk Gulim (TrueType)"="gulim.ttf"' \
  "registry file does not register Baekmuk Gulim"
assert_file_contains "$DRIVE_C/fix-korean-input.reg" \
  '"Malgun Gothic"="Baekmuk Gulim"' \
  "registry file does not replace Malgun Gothic"
assert_file_contains "$FLATPAK_LOG" \
  'reg add -b kakaotalk -k HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements -v 맑은 고딕 -d Baekmuk Gulim -t REG_SZ' \
  "localized Malgun Gothic alias was not applied"
pass "registers English and localized Korean font aliases"

first_hash="$(sha256sum "$DRIVE_C/fix-korean-input.reg")"
run_patcher >/dev/null || fail "second patch run failed"
second_hash="$(sha256sum "$DRIVE_C/fix-korean-input.reg")"
[[ "$first_hash" == "$second_hash" ]] || fail "second run changed registry output"
grep -Fq 'patch-kakaotalk-korean-input.sh' "$INSTALLER" ||
  fail "installer does not invoke the existing-install patch"
pass "is idempotent and wired into the installer"

printf '1..3\n'

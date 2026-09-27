#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TMP_ROOT="$(mktemp -d)"
readonly FIXTURE_STEPS="$TMP_ROOT/steps"
readonly TEST_HOME="$TMP_ROOT/home"
readonly FAKE_BIN="$TMP_ROOT/bin"
count=0

cleanup() {
  rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

pass() {
  count=$((count + 1))
  printf 'ok - %s\n' "$*"
}

keys_of() {
  grep -oE '^T\[[^]]+\]' "$1" | sort
}

mkdir -p -- "$FIXTURE_STEPS" "$TEST_HOME" "$FAKE_BIN"

diff <(keys_of "$ROOT_DIR/i18n/ko.sh") <(keys_of "$ROOT_DIR/i18n/en.sh") >/dev/null ||
  fail "ko and en define different keys: $(diff <(keys_of "$ROOT_DIR/i18n/ko.sh") <(keys_of "$ROOT_DIR/i18n/en.sh") | head -5 | tr '\n' ' ')"
pass "ko and en define exactly the same string keys"

if LC_ALL=C.UTF-8 grep -nP '[\x{AC00}-\x{D7A3}\x{3131}-\x{318E}]' "$ROOT_DIR/i18n/en.sh"; then
  fail "en strings contain Hangul"
fi
pass "en strings contain no Hangul"

for step in "$ROOT_DIR"/steps/[0-9]*.sh; do
  id="$(awk '/^register_step /{print $2; exit}' "$step")"
  for key in name desc; do
    for lang in ko en; do
      grep -q "^T\[$id\.$key\]=" "$ROOT_DIR/i18n/$lang.sh" || fail "$lang is missing $id.$key"
    done
  done
  if grep -q "^${id//-/_}_choices()" "$step"; then
    while IFS= read -r choice; do
      for lang in ko en; do
        grep -q "^T\[$id\.choice\.$choice\]=" "$ROOT_DIR/i18n/$lang.sh" || fail "$lang is missing $id.choice.$choice"
      done
    done < <(awk '/_choices\(\)/ { f = 1 } f && /printf/ { for (i = 3; i <= NF; i++) print $i; exit }' "$step")
    grep -q "^T\[$id\.choice\.title\]=" "$ROOT_DIR/i18n/ko.sh" || fail "ko is missing $id.choice.title"
  fi
done
pass "every step has a name, a description and labels for its choices in both languages"

(
  declare -A T=() STATUS=() ACTION=() REMOVABLE=()
  source "$ROOT_DIR/lib/common.sh"
  source "$ROOT_DIR/lib/ui.sh"
  STATUS[new]=missing ACTION[new]=none REMOVABLE[new]=yes
  ui_cycle new; [[ "${ACTION[new]}" == install ]] || fail "missing: [ ] -> [v]"
  ui_cycle new; [[ "${ACTION[new]}" == none ]] || fail "missing: [v] -> [ ]"
  STATUS[old]=installed ACTION[old]=keep REMOVABLE[old]=yes
  ui_cycle old; [[ "${ACTION[old]}" == install ]] || fail "installed: [-] -> [v]"
  ui_cycle old; [[ "${ACTION[old]}" == remove ]] || fail "installed: [v] -> [x]"
  ui_cycle old; [[ "${ACTION[old]}" == keep ]] || fail "installed: [x] -> [-]"
  STATUS[fixed]=outdated ACTION[fixed]=keep REMOVABLE[fixed]=no
  ui_cycle fixed; [[ "${ACTION[fixed]}" == install ]] || fail "not removable: [-] -> [v]"
  ui_cycle fixed; [[ "${ACTION[fixed]}" == keep ]] || fail "not removable: [v] skips [x]"
  [[ "$(ui_marker install)$(ui_marker keep)$(ui_marker remove)$(ui_marker none)" == '[v][-][x][ ]' ]] ||
    fail "markers"
)
pass "Space cycles [ ]<->[v] when missing, [-]->[v]->[x]->[-] when installed, and skips [x] when not removable"

cat >"$FIXTURE_STEPS/10-alpha.sh" <<'STEP'
register_step alpha required yes no
alpha_status() { echo missing; }
alpha_install() { echo alpha-installed >>"$FIXTURE_LOG"; }
alpha_remove() { echo alpha-removed >>"$FIXTURE_LOG"; }
STEP
cat >"$FIXTURE_STEPS/20-beta.sh" <<'STEP'
register_step beta recommended yes no
beta_status() { echo installed; }
beta_install() { echo beta-installed >>"$FIXTURE_LOG"; }
beta_remove() { echo beta-removed >>"$FIXTURE_LOG"; }
STEP
cat >"$FIXTURE_STEPS/30-gamma.sh" <<'STEP'
register_step gamma optional no no install
gamma_status() { echo outdated; }
gamma_choices() { printf '%s\n' first second; }
gamma_install() { echo "gamma-installed-$STEP_CHOICE" >>"$FIXTURE_LOG"; }
STEP
cat >"$FIXTURE_STEPS/40-delta.sh" <<'STEP'
register_step delta optional yes no
delta_visible() { return 1; }
delta_status() { echo missing; }
STEP

export OMARCHY_STARTER_STEPS_DIR="$FIXTURE_STEPS"
export OMARCHY_STARTER_STATE_DIR="$TMP_ROOT/state"
export FIXTURE_LOG="$TMP_ROOT/fixture.log"

list="$("$ROOT_DIR/install.sh" --list)"
expected='alpha required missing install
beta recommended installed keep
gamma optional outdated install'
[[ "$(awk '{print $1, $2, $3, $4}' <<<"$list")" == "$expected" ]] || fail "--list defaults: $list"
pass "--list: missing required starts [v], installed starts [-], hidden steps are not listed"

plan="$("$ROOT_DIR/install.sh" --dry-run --only alpha --remove beta --choice gamma=second </dev/null)"
grep -Fqx '  [x] beta.name' <<<"$plan" || fail "--dry-run lists removal: $plan"
grep -Fqx '  [v] alpha.name' <<<"$plan" || fail "--dry-run lists install: $plan"
grep -Fqx '  [-] gamma.name' <<<"$plan" || fail "--dry-run keeps unnamed installed items: $plan"
[[ ! -e "$FIXTURE_LOG" ]] || fail "--dry-run must not run steps"
pass "--dry-run with --only/--remove prints the exact plan and runs nothing"

if "$ROOT_DIR/install.sh" --dry-run --remove gamma </dev/null >/dev/null 2>&1; then
  fail "removing a non-removable step must fail"
fi
if "$ROOT_DIR/install.sh" --dry-run --only nope </dev/null >/dev/null 2>&1; then
  fail "an unknown step must fail"
fi
pass "unknown or non-removable items are rejected"

"$ROOT_DIR/install.sh" --only alpha,gamma --remove beta --choice gamma=second </dev/null >/dev/null
[[ "$(cat "$FIXTURE_LOG")" == $'beta-removed\nalpha-installed\ngamma-installed-second' ]] ||
  fail "execution order: $(tr '\n' ' ' <"$FIXTURE_LOG")"
pass "removals run first, then installs in step order, with the chosen option passed to the step"

if out="$(setsid "$ROOT_DIR/install.sh" </dev/null 2>&1)"; then
  fail "interactive mode without a terminal must refuse"
fi
grep -q -- '--all' <<<"$out" || fail "refusal names --all/--only: $out"
pass "without a terminal the checklist refuses instead of guessing"
unset OMARCHY_STARTER_STEPS_DIR

(
  declare -A T=()
  OMARCHY_STARTER_STATE_DIR="$TMP_ROOT/state2"
  source "$ROOT_DIR/lib/common.sh"
  f="$TMP_ROOT/rc"
  printf 'keep me\n' >"$f"
  block_write "$f" demo 'line one'
  block_write "$f" demo 'line two'
  [[ "$(grep -c 'omarchy-starter demo' "$f")" == 2 ]] || fail "block written once"
  grep -qx 'line two' "$f" && ! grep -qx 'line one' "$f" || fail "block replaced"
  block_write "$f" lua 'dofile("x")' --
  block_present "$f" lua -- || fail "lua block present"
  block_remove "$f" demo
  block_remove "$f" lua --
  [[ "$(cat "$f")" == 'keep me' ]] || fail "blocks removed cleanly: $(cat "$f")"
  [[ "$(str_width '한글 ab')" == 7 ]] || fail "Hangul counts two columns"
)
pass "marker blocks are idempotent, support Lua comments, remove cleanly; Hangul is two columns wide"

cat >"$FAKE_BIN/pacman" <<'PACMAN'
#!/usr/bin/env bash
[[ "${1:-}" == -Q ]] || exit 1
shift
for p in "$@"; do grep -qx "$p" "$FAKE_PKGS" 2>/dev/null || exit 1; done
PACMAN
cat >"$FAKE_BIN/omarchy" <<'OMARCHY'
#!/usr/bin/env bash
if [[ "$1 $2" == "pkg add" ]]; then shift 2; printf '%s\n' "$@" >>"$FAKE_PKGS"; exit 0; fi
if [[ "$1 $2" == "pkg drop" ]]; then shift 2; for p in "$@"; do sed -i "/^$p\$/d" "$FAKE_PKGS"; done; exit 0; fi
exit 1
OMARCHY
cat >"$FAKE_BIN/nano" <<'NANO'
#!/usr/bin/env bash
echo "NANO $*"
NANO
cat >"$FAKE_BIN/nvim" <<'NVIM'
#!/usr/bin/env bash
echo "NVIM $*"
NVIM
chmod +x "$FAKE_BIN"/*
export FAKE_PKGS="$TMP_ROOT/pkgs"
: >"$FAKE_PKGS"
mkdir -p -- "$TEST_HOME/.local/state/omarchy/defaults"
printf 'nvim\n' >"$TEST_HOME/.local/state/omarchy/defaults/editor"

run_step() {
  HOME="$TEST_HOME" PATH="$FAKE_BIN:/usr/share/omarchy/bin:$PATH" OMARCHY_STARTER_STATE_DIR="$TMP_ROOT/state3" \
    bash -c 'declare -A T=(); source "$1/lib/common.sh"; register_step() { :; }; source "$1/steps/20-nano.sh"; "nano_$2"' _ "$ROOT_DIR" "$1"
}

[[ "$(run_step status)" == missing ]] || fail "nano starts missing"
run_step install >/dev/null
[[ "$(run_step status)" == installed ]] || fail "nano installed"
if [[ -x /usr/share/omarchy/bin/omarchy-launch-editor ]]; then
  opened="$(HOME="$TEST_HOME" PATH="$FAKE_BIN:/usr/share/omarchy/bin:$PATH" /usr/share/omarchy/bin/omarchy-launch-editor --inline notes.txt)"
  [[ "$opened" == 'NANO notes.txt' ]] || fail "omarchy-launch-editor opens nano: $opened"
fi
run_step remove >/dev/null
[[ "$(cat "$TEST_HOME/.local/state/omarchy/defaults/editor")" == nvim ]] || fail "previous editor restored"
! grep -qx nano "$FAKE_PKGS" || fail "nano package we installed is dropped again"
if [[ -x /usr/share/omarchy/bin/omarchy-launch-editor ]]; then
  opened="$(HOME="$TEST_HOME" PATH="$FAKE_BIN:/usr/share/omarchy/bin:$PATH" /usr/share/omarchy/bin/omarchy-launch-editor --inline notes.txt)"
  [[ "$opened" == 'NVIM notes.txt' ]] || fail "after removal the previous editor opens: $opened"
fi
pass "nano step: omarchy-launch-editor opens nano after install and the previous editor after removal"

for f in "$ROOT_DIR"/install.sh "$ROOT_DIR"/lib/*.sh "$ROOT_DIR"/i18n/*.sh "$ROOT_DIR"/steps/*.sh; do
  bash -n "$f" || fail "syntax: $f"
done
pass "all installer files parse"

printf '1..%s\n' "$count"

#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly HELPER="$ROOT_DIR/manage-vpn-bypass-routes.sh"
readonly TMP_ROOT="$(mktemp -d)"
readonly FAKE_BIN="$TMP_ROOT/bin"
readonly FAKE_IP="$FAKE_BIN/ip"

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

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  [[ "$actual" == "$expected" ]] ||
    fail "$message (expected: <$expected>, actual: <$actual>)"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" == *"$needle"* ]] || fail "$message (missing: <$needle>)"
}

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fqx -- "$needle" "$file" || fail "$message (missing line: <$needle>)"
}

assert_file_empty() {
  local file="$1"
  local message="$2"

  [[ ! -s "$file" ]] || fail "$message"
}

if [[ ! -x "$HELPER" ]]; then
  printf 'not ok - helper is absent or not executable: %s\n' "$HELPER" >&2
  exit 1
fi

mkdir -p -- "$FAKE_BIN"
cat >"$FAKE_IP" <<'FAKE_IP_EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$FAKE_IP_LOG"

family="$1"
shift
[[ "$family" == "-4" || "$family" == "-6" ]] || exit 64
json_output=false
if [[ "${1:-}" == "-j" ]]; then
  json_output=true
  shift
fi
[[ "${1:-}" == "route" ]] || exit 64
shift

if [[ "$family" == "-4" ]]; then
  defaults="$FAKE_DEFAULT4"
  table52="$FAKE_TABLE52_4"
  routes="$FAKE_ROUTES4"
else
  defaults="$FAKE_DEFAULT6"
  table52="$FAKE_TABLE52_6"
  routes="$FAKE_ROUTES6"
fi

emit_routes_json() {
  local first=true line destination gateway device protocol metric token
  local -a words

  printf '['
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    read -r -a words <<<"$line"
    destination="${words[0]}"
    gateway=""
    device=""
    protocol=""
    metric=""
    for (( token=1; token<${#words[@]}; token++ )); do
      case "${words[token]}" in
        via) gateway="${words[token+1]:-}" ;;
        dev) device="${words[token+1]:-}" ;;
        proto) protocol="${words[token+1]:-}" ;;
        metric) metric="${words[token+1]:-}" ;;
      esac
    done
    $first || printf ','
    first=false
    printf '{"dst":"%s","gateway":"%s","dev":"%s","protocol":"%s","metric":%s,"flags":[]}' \
      "$destination" "$gateway" "$device" "$protocol" "${metric:-0}"
  done
  printf ']\n'
}

case "${1:-}" in
  show)
    shift
    if [[ "${1:-}" == "default" ]]; then
      cat -- "$defaults"
    elif [[ "${1:-}" == "table" && "${2:-}" == "52" ]]; then
      cat -- "$table52"
    elif [[ "${1:-}" == "table" && "${2:-}" == "main" && "${3:-}" == "default" ]]; then
      if [[ "$(head -c 1 -- "$defaults")" == "[" ]]; then
        cat -- "$defaults"
      else
        emit_routes_json <"$defaults"
      fi
    elif [[ "${1:-}" == "table" && "${2:-}" == "main" && "${3:-}" == "exact" && -n "${4:-}" ]]; then
      if $json_output; then
        awk -v destination="$4" '$1 == destination { print }' "$routes" | emit_routes_json
      else
        awk -v destination="$4" '$1 == destination { print }' "$routes"
      fi
    else
      exit 64
    fi
    ;;
  get)
    destination="${2:-}"
    [[ -n "$destination" ]] || exit 64
    if grep -Fqx -- "$destination" "$FAKE_TS_GET"; then
      printf '%s dev tailscale0 table 52 src %s\n' "$destination" "$([[ "$family" == "-4" ]] && printf '100.64.0.1' || printf 'fd7a:115c:a1e0::1')"
    else
      first_default="$(head -n 1 -- "$defaults")"
      [[ -n "$first_default" ]] || exit 2
      printf '%s %s\n' "$destination" "${first_default#default }"
    fi
    ;;
  add)
    shift
    spec="$*"
    printf 'MUTATE %s route add %s\n' "$family" "$spec" >>"$FAKE_MUTATION_LOG"
    if [[ -s "$FAKE_FAIL_ADD" ]] &&
      { grep -Fqx -- "${spec%% *}" "$FAKE_FAIL_ADD" || grep -Fqx -- "$spec" "$FAKE_FAIL_ADD"; }
    then
      exit 2
    fi
    printf '%s\n' "$spec" >>"$routes"
    if [[ -s "$FAKE_SIGNAL_ADD" ]] &&
      { grep -Fqx -- "${spec%% *}" "$FAKE_SIGNAL_ADD" || grep -Fqx -- "$spec" "$FAKE_SIGNAL_ADD"; }
    then
      helper_pid="$(awk '{print $4}' "/proc/$PPID/stat")"
      kill -TERM "$helper_pid"
    fi
    ;;
  del)
    shift
    spec="$*"
    printf 'MUTATE %s route del %s\n' "$family" "$spec" >>"$FAKE_MUTATION_LOG"
    if [[ -s "$FAKE_FAIL_DEL" ]] &&
      { grep -Fqx -- "${spec%% *}" "$FAKE_FAIL_DEL" || grep -Fqx -- "$spec" "$FAKE_FAIL_DEL"; }
    then
      exit 2
    fi
    temporary="${routes}.tmp.$$"
    awk -v spec="$spec" '$0 != spec { print }' "$routes" >"$temporary"
    mv -- "$temporary" "$routes"
    ;;
  *)
    exit 64
    ;;
esac
FAKE_IP_EOF
chmod +x -- "$FAKE_IP"

case_number=0
setup_case() {
  case_number=$((case_number + 1))
  CASE_DIR="$TMP_ROOT/case-$case_number"
  mkdir -p -- "$CASE_DIR"
  CONFIG="$CASE_DIR/routes.conf"
  STATE="$CASE_DIR/routes.state"
  FAKE_IP_LOG="$CASE_DIR/ip.log"
  FAKE_MUTATION_LOG="$CASE_DIR/mutations.log"
  FAKE_DEFAULT4="$CASE_DIR/default4"
  FAKE_DEFAULT6="$CASE_DIR/default6"
  FAKE_TABLE52_4="$CASE_DIR/table52-4"
  FAKE_TABLE52_6="$CASE_DIR/table52-6"
  FAKE_ROUTES4="$CASE_DIR/routes4"
  FAKE_ROUTES6="$CASE_DIR/routes6"
  FAKE_TS_GET="$CASE_DIR/tailscale-get"
  FAKE_FAIL_ADD="$CASE_DIR/fail-add"
  FAKE_FAIL_DEL="$CASE_DIR/fail-del"
  FAKE_SIGNAL_ADD="$CASE_DIR/signal-add"
  export CASE_DIR CONFIG STATE FAKE_IP_LOG FAKE_MUTATION_LOG
  export FAKE_DEFAULT4 FAKE_DEFAULT6 FAKE_TABLE52_4 FAKE_TABLE52_6
  export FAKE_ROUTES4 FAKE_ROUTES6 FAKE_TS_GET FAKE_FAIL_ADD FAKE_FAIL_DEL FAKE_SIGNAL_ADD
  : >"$CONFIG"
  : >"$FAKE_IP_LOG"
  : >"$FAKE_MUTATION_LOG"
  : >"$FAKE_TABLE52_4"
  : >"$FAKE_TABLE52_6"
  : >"$FAKE_ROUTES4"
  : >"$FAKE_ROUTES6"
  : >"$FAKE_TS_GET"
  : >"$FAKE_FAIL_ADD"
  : >"$FAKE_FAIL_DEL"
  : >"$FAKE_SIGNAL_ADD"
  printf 'default via 192.0.2.1 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
  printf 'default via 2001:db8:ffff::1 dev eth0 proto ra metric 100 pref medium\n' >"$FAKE_DEFAULT6"
}

run_helper() {
  unshare -Ur --map-root-user \
    env DOC_NEWBIE_TEST_HARNESS=1 \
    DOC_NEWBIE_STATE_FILE="$STATE" \
    DOC_NEWBIE_TEST_IP="$FAKE_IP" \
    "$HELPER" --config "$CONFIG" "$@"
}

run_helper_nonroot() {
  DOC_NEWBIE_TEST_HARNESS=1 \
    DOC_NEWBIE_STATE_FILE="$STATE" \
    DOC_NEWBIE_TEST_IP="$FAKE_IP" \
    "$HELPER" --config "$CONFIG" "$@"
}

setup_case
printf '# comment\r\n\r\n192.0.2.0/24\r\n203.0.113.7/32\r\n2001:db8::/32\r\n2001:db8::7/128\r\n192.0.2.0/24\r\n' >"$CONFIG"
output="$(run_helper_nonroot list)" || fail "valid unprivileged list command failed"
assert_eq $'192.0.2.0/24\n203.0.113.7/32\n2001:db8::/32\n2001:db8::7/128' "$output" "list normalizes, sorts, and deduplicates IPv4/IPv6 CIDRs"
run_helper_nonroot validate >/dev/null || fail "valid unprivileged CRLF config did not validate"
assert_file_empty "$FAKE_IP_LOG" "validate/list called ip"
assert_file_empty "$FAKE_MUTATION_LOG" "validate/list mutated routes"
pass "parser accepts comments, blanks, CRLF, IPv4/IPv6, /32, /128, and duplicates"

for invalid in \
  'example.com/32' \
  'hostname' \
  '192.0.2.0/33' \
  '2001:db8::/129' \
  '192.0.2.7/24' \
  '192.0.2.0/24 trailing' \
  '192.0.2.0/24;touch-pwned' \
  '192.0.2.0' \
  '2001:db8::'; do
  setup_case
  printf '%s\n' "$invalid" >"$CONFIG"
  if output="$(run_helper_nonroot validate 2>&1)"; then
    fail "invalid config was accepted: $invalid"
  fi
  assert_contains "$output" "line 1" "invalid input error did not identify its line"
  [[ "$output" != *"touch-pwned"* ]] || fail "invalid executable text leaked into diagnostics"
  assert_file_empty "$FAKE_IP_LOG" "invalid parsing called ip"
  assert_file_empty "$FAKE_MUTATION_LOG" "invalid parsing mutated routes"
done

setup_case
marker="$CASE_DIR/command-was-executed"
printf '192.0.2.0/24;touch %s\n' "$marker" >"$CONFIG"
if output="$(run_helper_nonroot validate 2>&1)"; then
  fail "shell command text was accepted"
fi
[[ ! -e "$marker" ]] || fail "config command text was executed"
[[ "$output" != *"$marker"* ]] || fail "config command text leaked into diagnostics"
printf '192.0.2.0/24\001\n' >"$CONFIG"
if output="$(run_helper_nonroot validate 2>&1)"; then
  fail "control-character input was accepted"
fi
if printf '%s' "$output" | LC_ALL=C grep -qP '[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'; then
  fail "control-character input leaked into diagnostics"
fi
pass "parser rejects malformed CIDRs, hostnames, bare IPs, trailing tokens, and metacharacters"

setup_case
printf '192.0.2.0/24\n' >"$CONFIG"
if output="$(run_helper_nonroot apply 2>&1)"; then
  fail "non-root apply succeeded"
fi
assert_contains "$output" "root" "non-root apply rejection was unclear"
assert_file_empty "$FAKE_MUTATION_LOG" "non-root apply mutated routes"
pass "apply rejects non-root execution"

setup_case
printf '192.0.2.0/24\n' >"$CONFIG"
: >"$FAKE_DEFAULT4"
if run_helper apply >/dev/null 2>&1; then
  fail "apply succeeded without an ordinary IPv4 default"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "missing IPv4 default caused mutation"
setup_case
printf '2001:db8::/32\n' >"$CONFIG"
: >"$FAKE_DEFAULT6"
if run_helper apply >/dev/null 2>&1; then
  fail "apply succeeded without an ordinary IPv6 default"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "missing IPv6 default caused mutation"

setup_case
printf '198.51.100.0/24\n2001:db8:100::/48\n' >"$CONFIG"
printf '# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.1\teth0\t42760\n6\t2001:db8:100::/48\t2001:db8:ffff::1\teth0\t42760\n' >"$STATE"
printf '198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760\n' >"$FAKE_ROUTES4"
printf '2001:db8:100::/48 via 2001:db8:ffff::1 dev eth0 proto static metric 42760\n' >"$FAKE_ROUTES6"
: >"$FAKE_DEFAULT6"
state_before="$(cat -- "$STATE")"
routes4_before="$(cat -- "$FAKE_ROUTES4")"
routes6_before="$(cat -- "$FAKE_ROUTES6")"
if run_helper apply >/dev/null 2>&1; then
  fail "mixed apply succeeded without an IPv6 default"
fi
assert_eq "$state_before" "$(cat -- "$STATE")" "missing IPv6 default changed mixed state"
assert_eq "$routes4_before" "$(cat -- "$FAKE_ROUTES4")" "missing IPv6 default changed IPv4 route"
assert_eq "$routes6_before" "$(cat -- "$FAKE_ROUTES6")" "missing IPv6 default changed IPv6 route"
assert_file_empty "$FAKE_MUTATION_LOG" "mixed missing-family preflight mutated routes"
pass "apply preflights every required family and fails atomically when a default is missing"

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
printf 'default via 192.0.2.1 dev eth0 metric 100\ndefault via 192.0.2.254 dev eth1 metric 100\n' >"$FAKE_DEFAULT4"
if run_helper apply >/dev/null 2>&1; then
  fail "equal-metric distinct ordinary defaults were accepted"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "ambiguous defaults caused mutation"
setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
printf '%s\n' '[{"dst":"default","metric":100,"nexthops":[{"gateway":"192.0.2.1","dev":"eth0"},{"gateway":"192.0.2.254","dev":"eth1"}],"flags":[]}]' >"$FAKE_DEFAULT4"
if run_helper apply >/dev/null 2>&1; then
  fail "unsupported multipath default was accepted"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "multipath default caused mutation"
pass "structured default discovery rejects equal-best ambiguity and unsupported multipath"

setup_case
printf 'default via 10.8.0.1 dev tun0 metric 1\ndefault via 192.0.2.1 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
printf 'default via 2001:db8:ffff::2 dev wg0 metric 1\ndefault via 2001:db8:ffff::1 dev eth0 proto ra metric 100 pref medium\n' >"$FAKE_DEFAULT6"
printf '198.51.100.0/24\n2001:db8:1::/64\n' >"$CONFIG"
run_helper apply >/dev/null || fail "mixed-family apply failed"
assert_file_contains "$FAKE_MUTATION_LOG" 'MUTATE -4 route add 198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760' "wrong IPv4 route command"
assert_file_contains "$FAKE_MUTATION_LOG" 'MUTATE -6 route add 2001:db8:1::/64 via 2001:db8:ffff::1 dev eth0 proto static metric 42760' "wrong IPv6 route command"
first_mutations="$(wc -l <"$FAKE_MUTATION_LOG")"
run_helper apply >/dev/null || fail "idempotent second apply failed"
assert_eq "$first_mutations" "$(wc -l <"$FAKE_MUTATION_LOG")" "second apply changed routes"
run_helper remove >/dev/null || fail "remove failed"
assert_file_contains "$FAKE_MUTATION_LOG" 'MUTATE -4 route del 198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760' "wrong IPv4 delete command"
assert_file_contains "$FAKE_MUTATION_LOG" 'MUTATE -6 route del 2001:db8:1::/64 via 2001:db8:ffff::1 dev eth0 proto static metric 42760' "wrong IPv6 delete command"
after_remove="$(wc -l <"$FAKE_MUTATION_LOG")"
rm -f -- "$CONFIG"
run_helper remove >/dev/null || fail "idempotent second remove without a config file failed"
assert_eq "$after_remove" "$(wc -l <"$FAKE_MUTATION_LOG")" "second remove changed routes"
pass "apply/remove are idempotent and generate exact IPv4/IPv6 commands"

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
printf '198.51.100.0/24 via 192.0.2.254 dev eth9 proto static metric 12345\n' >"$FAKE_ROUTES4"
if run_helper apply >/dev/null 2>&1; then
  fail "apply replaced an unmanaged existing route"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "unmanaged route refusal mutated routes"
pass "apply refuses an unmanaged existing route"

setup_case
printf '100.64.0.0/10\n' >"$CONFIG"
printf '100.64.0.0/10 dev tailscale0\n' >"$FAKE_TABLE52_4"
if run_helper apply >/dev/null 2>&1; then
  fail "apply accepted a table-52-owned destination"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "table-52 refusal mutated routes"
setup_case
printf '203.0.113.0/24\n' >"$CONFIG"
printf '203.0.113.0\n' >"$FAKE_TS_GET"
if run_helper apply >/dev/null 2>&1; then
  fail "apply accepted a tailscale0 route-get destination"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "tailscale0 refusal mutated routes"
pass "apply preserves tailscale0 and table 52 ownership"

setup_case
printf '198.51.100.0/24\n203.0.113.0/24\n192.0.2.0/24\n' >"$CONFIG"
printf '# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.1\teth0\t42760\n' >"$STATE"
printf '198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760\n' >"$FAKE_ROUTES4"
printf '203.0.113.0/24\n' >"$FAKE_FAIL_ADD"
state_before="$(cat -- "$STATE")"
if run_helper apply >/dev/null 2>&1; then
  fail "mid-apply injected failure unexpectedly succeeded"
fi
assert_eq "$state_before" "$(cat -- "$STATE")" "failed apply changed prior state"
assert_eq '198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760' "$(cat -- "$FAKE_ROUTES4")" "failed apply did not restore prior routes exactly"
assert_file_contains "$FAKE_MUTATION_LOG" 'MUTATE -4 route add 192.0.2.0/24 via 192.0.2.1 dev eth0 proto static metric 42760' "first new route was not attempted"
assert_file_contains "$FAKE_MUTATION_LOG" 'MUTATE -4 route del 192.0.2.0/24 via 192.0.2.1 dev eth0 proto static metric 42760' "new route was not rolled back"

setup_case
printf '# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.1\teth0\t42760\n4\t203.0.113.0/24\t192.0.2.1\teth0\t42760\n' >"$STATE"
printf '198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760\n203.0.113.0/24 via 192.0.2.1 dev eth0 proto static metric 42760\n' >"$FAKE_ROUTES4"
printf '203.0.113.0/24\n' >"$FAKE_FAIL_DEL"
state_before="$(cat -- "$STATE")"
if run_helper remove >/dev/null 2>&1; then
  fail "mid-remove injected failure unexpectedly succeeded"
fi
assert_eq "$state_before" "$(cat -- "$STATE")" "failed remove changed prior state"
assert_eq $'198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760\n203.0.113.0/24 via 192.0.2.1 dev eth0 proto static metric 42760' "$(LC_ALL=C sort "$FAKE_ROUTES4")" "failed remove did not restore routes"
assert_file_contains "$FAKE_MUTATION_LOG" 'MUTATE -4 route add 198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760' "removed route was not restored"

setup_case
printf '198.51.100.0/24\n203.0.113.0/24\n' >"$CONFIG"
printf '203.0.113.0/24\n' >"$FAKE_SIGNAL_ADD"
if run_helper apply >/dev/null 2>&1; then
  fail "interrupted apply unexpectedly succeeded"
fi
assert_file_empty "$FAKE_ROUTES4" "interrupted apply left partial routes"
[[ ! -e "$STATE" ]] || fail "interrupted apply created state"
pass "mid-operation failures and interruption roll back without changing prior state"

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
printf '# doc-newbie vpn bypass routes state v2\nmalformed stale state\n' >"$STATE"
if run_helper apply >/dev/null 2>&1; then
  fail "apply accepted stale malformed state"
fi
if run_helper remove >/dev/null 2>&1; then
  fail "remove accepted stale malformed state"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "stale state handling mutated routes"

setup_case
printf '# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.1\teth0\t42760\n' >"$STATE"
printf '198.51.100.0/24 via 192.0.2.254 dev eth9 proto static metric 42760\n' >"$FAKE_ROUTES4"
if run_helper remove >/dev/null 2>&1; then
  fail "remove accepted a live route that differed from helper state"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "stale live-route refusal mutated routes"

setup_case
printf '# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.1\teth0\t42760\n' >"$STATE"
printf '198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760\n198.51.100.0/24 via 192.0.2.254 dev eth9 proto static metric 12345\n' >"$FAKE_ROUTES4"
if run_helper remove >/dev/null 2>&1; then
  fail "remove accepted an unmanaged same-prefix sibling"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "sibling-route refusal deleted a route"
assert_eq "2" "$(wc -l <"$FAKE_ROUTES4")" "sibling-route refusal changed live routes"
pass "stale, mismatched, or ambiguous sibling routes fail closed without mutation"

setup_case
state_target="$CASE_DIR/state-target"
printf '# doc-newbie vpn bypass routes state v2\n' >"$state_target"
ln -s -- "$state_target" "$STATE"
if run_helper remove >/dev/null 2>&1; then
  fail "remove accepted a symlink state file"
fi
rm -f -- "$STATE"
printf '# doc-newbie vpn bypass routes state v2\n' >"$STATE"
chmod 666 -- "$STATE"
if run_helper remove >/dev/null 2>&1; then
  fail "remove accepted group/other-writable state"
fi
output="$(unshare -Ur --map-root-user env \
  DOC_NEWBIE_TEST_HARNESS=1 \
  DOC_NEWBIE_STATE_FILE=/etc/hosts \
  DOC_NEWBIE_TEST_IP="$FAKE_IP" \
  "$HELPER" remove 2>&1 || true)"
assert_contains "$output" "not owned by root" "wrong-owner state attack was not rejected"
assert_file_empty "$FAKE_MUTATION_LOG" "state-file attack handling mutated routes"
pass "symlink, unsafe-mode, and wrong-owner state-file attacks fail closed"

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
if unshare -Urn --map-root-user env PATH="$FAKE_BIN:$PATH" \
  "$HELPER" --config "$CONFIG" apply >/dev/null 2>&1; then
  fail "production-path hardening fixture unexpectedly applied without a default"
fi
assert_file_empty "$FAKE_IP_LOG" "production execution used a PATH-injected ip binary"
assert_file_empty "$FAKE_MUTATION_LOG" "PATH-hijack fixture mutated routes"
pass "production execution ignores PATH-injected ip and test overrides outside the safe harness"

old_state=$'# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.1\teth0\t42760'
old_route='198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760'
new_route='198.51.100.0/24 via 192.0.2.254 dev eth0 proto static metric 42760'

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
printf 'default via 192.0.2.254 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
printf '%s\n' "$old_state" >"$STATE"
printf '%s\n' "$old_route" >"$FAKE_ROUTES4"
printf '%s\n' "$old_route" >"$FAKE_FAIL_DEL"
if run_helper apply >/dev/null 2>&1; then
  fail "migration with injected old-route delete failure succeeded"
fi
assert_eq "$old_state" "$(cat -- "$STATE")" "delete-failed migration changed state"
assert_eq "$old_route" "$(cat -- "$FAKE_ROUTES4")" "delete-failed migration changed old route"

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
printf 'default via 192.0.2.254 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
printf '%s\n' "$old_state" >"$STATE"
printf '%s\n' "$old_route" >"$FAKE_ROUTES4"
printf '%s\n' "$new_route" >"$FAKE_FAIL_ADD"
if run_helper apply >/dev/null 2>&1; then
  fail "migration with injected new-route add failure succeeded"
fi
assert_eq "$old_state" "$(cat -- "$STATE")" "add-failed migration changed state"
assert_eq "$old_route" "$(cat -- "$FAKE_ROUTES4")" "add-failed migration did not restore old route"

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
printf 'default via 192.0.2.254 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
printf '%s\n' "$old_state" >"$STATE"
printf '%s\n' "$old_route" >"$FAKE_ROUTES4"
printf '%s\n' "$new_route" >"$FAKE_SIGNAL_ADD"
if run_helper apply >/dev/null 2>&1; then
  fail "TERM-interrupted migration succeeded"
fi
assert_eq "$old_state" "$(cat -- "$STATE")" "interrupted migration changed state"
assert_eq "$old_route" "$(cat -- "$FAKE_ROUTES4")" "interrupted migration did not restore old route"

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
printf 'default via 192.0.2.254 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
printf '%s\n' "$old_state" >"$STATE"
printf '%s\n%s\n' "$old_route" '198.51.100.0/24 via 192.0.2.99 dev eth9 proto static metric 12345' >"$FAKE_ROUTES4"
if run_helper apply >/dev/null 2>&1; then
  fail "migration proceeded with an unmanaged same-prefix sibling"
fi
assert_file_empty "$FAKE_MUTATION_LOG" "blocked migration touched a sibling route"
assert_eq "2" "$(wc -l <"$FAKE_ROUTES4")" "blocked migration changed sibling routes"
assert_eq "$old_state" "$(cat -- "$STATE")" "blocked migration changed state"

multi_state=$'# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.1\teth0\t42760\n4\t203.0.113.0/24\t192.0.2.1\teth0\t42760'
multi_old_routes=$'198.51.100.0/24 via 192.0.2.1 dev eth0 proto static metric 42760\n203.0.113.0/24 via 192.0.2.1 dev eth0 proto static metric 42760'
second_new_route='203.0.113.0/24 via 192.0.2.254 dev eth0 proto static metric 42760'

setup_case
printf '198.51.100.0/24\n203.0.113.0/24\n' >"$CONFIG"
printf 'default via 192.0.2.254 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
printf '%s\n' "$multi_state" >"$STATE"
printf '%s\n' "$multi_old_routes" >"$FAKE_ROUTES4"
printf '100.64.0.0/10 dev tailscale0\n' >"$FAKE_TABLE52_4"
printf '%s\n' "$second_new_route" >"$FAKE_FAIL_ADD"
if run_helper apply >/dev/null 2>&1; then
  fail "multi-route migration add failure succeeded"
fi
assert_eq "$multi_state" "$(cat -- "$STATE")" "multi-route add failure changed state"
assert_eq "$multi_old_routes" "$(LC_ALL=C sort "$FAKE_ROUTES4")" "multi-route add failure did not restore all old routes"
assert_eq '100.64.0.0/10 dev tailscale0' "$(cat -- "$FAKE_TABLE52_4")" "multi-route rollback changed table 52 sentinel"

setup_case
printf '198.51.100.0/24\n203.0.113.0/24\n' >"$CONFIG"
printf 'default via 192.0.2.254 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
printf '%s\n' "$multi_state" >"$STATE"
printf '%s\n' "$multi_old_routes" >"$FAKE_ROUTES4"
printf '100.64.0.0/10 dev tailscale0\n' >"$FAKE_TABLE52_4"
printf '%s\n' "$second_new_route" >"$FAKE_SIGNAL_ADD"
if run_helper apply >/dev/null 2>&1; then
  fail "multi-route TERM migration succeeded"
fi
assert_eq "$multi_state" "$(cat -- "$STATE")" "multi-route TERM changed state"
assert_eq "$multi_old_routes" "$(LC_ALL=C sort "$FAKE_ROUTES4")" "multi-route TERM did not restore all old routes"
assert_eq '100.64.0.0/10 dev tailscale0' "$(cat -- "$FAKE_TABLE52_4")" "multi-route TERM changed table 52 sentinel"

setup_case
printf '198.51.100.0/24\n2001:db8:100::/48\n' >"$CONFIG"
printf 'default via 192.0.2.254 dev eth0 proto dhcp metric 100\n' >"$FAKE_DEFAULT4"
printf '# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.1\teth0\t42760\n6\t2001:db8:100::/48\t2001:db8:ffff::1\teth0\t42760\n' >"$STATE"
printf '%s\n' "$old_route" >"$FAKE_ROUTES4"
printf '2001:db8:100::/48 via 2001:db8:ffff::1 dev eth0 proto static metric 42760\n' >"$FAKE_ROUTES6"
run_helper apply >/dev/null || fail "single-family migration in mixed config failed"
assert_eq $'# doc-newbie vpn bypass routes state v2\n4\t198.51.100.0/24\t192.0.2.254\teth0\t42760\n6\t2001:db8:100::/48\t2001:db8:ffff::1\teth0\t42760' "$(cat -- "$STATE")" "successful migration did not update the existing state row"
assert_eq "$new_route" "$(cat -- "$FAKE_ROUTES4")" "IPv4 migration did not use current default"
assert_eq '2001:db8:100::/48 via 2001:db8:ffff::1 dev eth0 proto static metric 42760' "$(cat -- "$FAKE_ROUTES6")" "IPv4 migration changed IPv6 route"
if grep -Fq 'MUTATE -6' "$FAKE_MUTATION_LOG"; then
  fail "IPv4-only migration emitted an IPv6 mutation"
fi
migration_mutations="$(wc -l <"$FAKE_MUTATION_LOG")"
run_helper apply >/dev/null || fail "post-migration apply was not idempotent"
assert_eq "$migration_mutations" "$(wc -l <"$FAKE_MUTATION_LOG")" "next apply repeated a completed migration"
run_helper remove >/dev/null || fail "post-migration remove did not use updated state"
pass "migration failures, TERM, siblings, multi-route rollback, and family independence preserve transaction invariants"

if grep -Eiq '(^| )(flush|replace)( |$)|route del default|route del table|route del .*tailscale' "$TMP_ROOT"/case-*/mutations.log; then
  fail "a broad or Tailscale route mutation was generated"
fi
pass "no broad route flush, replacement, or Tailscale deletion is generated"

setup_case
printf '198.51.100.0/24\n2001:db8:100::/48\n' >"$CONFIG"
netns_blocker="$CASE_DIR/unshare-blocker.txt"
if unshare -Urn --map-root-user true 2>"$netns_blocker"; then
  if ! unshare -Urn --map-root-user \
    bash -eu -c '
      export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
      helper="$1"
      config="$2"
      state="$3"
      ip link set lo up
      ip link add ordinary0 type dummy
      ip address add 192.0.2.2/24 dev ordinary0
      ip -6 address add 2001:db8:ffff::2/64 dev ordinary0
      ip link set ordinary0 up
      ip -4 route add default via 192.0.2.1 dev ordinary0
      ip -6 route add default via 2001:db8:ffff::1 dev ordinary0

      DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
      ip -j -4 route show table main exact 198.51.100.0/24 | python3 -c '\''import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["gateway"]=="192.0.2.1" and r[0]["dev"]=="ordinary0" and r[0]["protocol"]=="static" and r[0]["metric"]==42760'\''
      ip -j -6 route show table main exact 2001:db8:100::/48 | python3 -c '\''import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["gateway"]=="2001:db8:ffff::1" and r[0]["dev"]=="ordinary0" and r[0]["protocol"]=="static" and r[0]["metric"]==42760 and r[0]["pref"]=="medium"'\''
      ip -6 route show table main exact 2001:db8:100::/48 | grep -Fq "proto static metric 42760 pref medium"

      DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
      ip -6 route add 2001:db8:100::/48 via 2001:db8:ffff::1 dev ordinary0 proto static metric 12345
      if DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" remove >/dev/null 2>&1; then
        exit 1
      fi
      test "$(ip -j -6 route show table main exact 2001:db8:100::/48 | python3 -c '\''import json,sys; print(len(json.load(sys.stdin)))'\'')" = 2
      test -e "$state"
      ip -6 route del 2001:db8:100::/48 via 2001:db8:ffff::1 dev ordinary0 proto static metric 12345

      DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" remove >/dev/null
      test -z "$(ip -4 route show table main exact 198.51.100.0/24)"
      test -z "$(ip -6 route show table main exact 2001:db8:100::/48)"
      test ! -e "$state"

      before4="$(ip -j -4 route show table main)"
      before6="$(ip -j -6 route show table main)"
      printf "example.invalid/32\\n" >"$config"
      if DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null 2>&1; then
        exit 1
      fi
      test "$before4" = "$(ip -j -4 route show table main)"
      test "$before6" = "$(ip -j -6 route show table main)"
    ' test-manage-vpn-bypass-routes.sh-netns "$HELPER" "$CONFIG" "$STATE"
  then
    fail "real isolated mixed-family network-namespace regression failed"
  fi
  pass "real IPv4+IPv6 namespace handles kernel attributes, idempotency, sibling refusal, and exact removal"
else
  printf 'ok - network namespace unavailable: %s\n' "$(tr '\n' ' ' <"$netns_blocker")"
fi

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
if unshare -Urn --map-root-user true 2>"$CASE_DIR/unshare-blocker.txt"; then
  if ! unshare -Urn --map-root-user bash -eu -c '
    helper="$1"; config="$2"; state="$3"
    ip link add ordinary0 type dummy
    ip address add 192.0.2.2/24 dev ordinary0
    ip link set ordinary0 up
    ip -4 route add default via 192.0.2.1 dev ordinary0 metric 100
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
    ip -4 route del 198.51.100.0/24 via 192.0.2.1 dev ordinary0 proto static metric 42760
    ip -4 route del default via 192.0.2.1 dev ordinary0 metric 100
    ip -4 route add default via 192.0.2.254 dev ordinary0 metric 100
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
    ip -j -4 route show table main exact 198.51.100.0/24 | python3 -c '\''import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["gateway"]=="192.0.2.254" and r[0]["dev"]=="ordinary0" and r[0]["metric"]==42760'\''
    grep -Fq "192.0.2.254" "$state"
    ! grep -Fq "192.0.2.1" "$state"
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" remove >/dev/null
    test ! -e "$state"
  ' test-manage-vpn-bypass-routes.sh-dynamic-missing "$HELPER" "$CONFIG" "$STATE"; then
    fail "real missing-route changed-default regression failed"
  fi
  pass "real missing helper route is reinstalled only through the current changed default"
else
  printf 'ok - network namespace unavailable: %s\n' "$(tr '\n' ' ' <"$CASE_DIR/unshare-blocker.txt")"
fi

setup_case
printf '198.51.100.0/24\n2001:db8:100::/48\n' >"$CONFIG"
if unshare -Urn --map-root-user true 2>"$CASE_DIR/unshare-blocker.txt"; then
  if ! unshare -Urn --map-root-user bash -eu -c '
    helper="$1"; config="$2"; state="$3"
    ip link add v4ordinary type dummy
    ip address add 192.0.2.2/24 dev v4ordinary
    ip link set v4ordinary up
    ip link add v6ordinary type dummy
    ip -6 address add 2001:db8:ffff::2/64 dev v6ordinary
    ip link set v6ordinary up
    ip -4 route add default via 192.0.2.1 dev v4ordinary metric 100
    ip -6 route add default via 2001:db8:ffff::1 dev v6ordinary metric 100
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
    ip -4 route del default via 192.0.2.1 dev v4ordinary metric 100
    ip -4 route add default via 192.0.2.254 dev v4ordinary metric 100
    ip -4 route add 198.51.100.0/24 via 192.0.2.99 dev v4ordinary proto static metric 12345
    state_before="$(cat -- "$state")"
    routes4_before="$(ip -j -4 route show table main exact 198.51.100.0/24)"
    routes6_before="$(ip -j -6 route show table main exact 2001:db8:100::/48)"
    if DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null 2>&1; then exit 1; fi
    test "$state_before" = "$(cat -- "$state")"
    test "$routes4_before" = "$(ip -j -4 route show table main exact 198.51.100.0/24)"
    test "$routes6_before" = "$(ip -j -6 route show table main exact 2001:db8:100::/48)"
    ip -4 route del 198.51.100.0/24 via 192.0.2.99 dev v4ordinary proto static metric 12345
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
    ip -j -4 route show table main exact 198.51.100.0/24 | python3 -c '\''import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["gateway"]=="192.0.2.254" and r[0]["metric"]==42760'\''
    ip -j -6 route show table main exact 2001:db8:100::/48 | python3 -c '\''import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["gateway"]=="2001:db8:ffff::1" and r[0]["metric"]==42760'\''
    grep -Fq "192.0.2.254" "$state"
    grep -Fq "2001:db8:ffff::1" "$state"
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" remove >/dev/null
    test ! -e "$state"
  ' test-manage-vpn-bypass-routes.sh-live-mixed "$HELPER" "$CONFIG" "$STATE"; then
    fail "real live mixed-family migration regression failed"
  fi
  pass "real live migration changes only IPv4 while IPv6 identity remains untouched"
else
  printf 'ok - network namespace unavailable: %s\n' "$(tr '\n' ' ' <"$CASE_DIR/unshare-blocker.txt")"
fi

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
if unshare -Urn --map-root-user true 2>"$CASE_DIR/unshare-blocker.txt"; then
  if ! unshare -Urn --map-root-user bash -eu -c '
    helper="$1"; config="$2"; state="$3"
    ip link add oldordinary type dummy
    ip address add 192.0.2.2/24 dev oldordinary
    ip link set oldordinary up
    ip -4 route add default via 192.0.2.1 dev oldordinary metric 100
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
    ip link del oldordinary
    ip link add newordinary type dummy
    ip address add 198.18.0.2/24 dev newordinary
    ip link set newordinary up
    ip -4 route add default via 198.18.0.1 dev newordinary metric 100
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" apply >/dev/null
    ip -j -4 route show table main exact 198.51.100.0/24 | python3 -c '\''import json,sys; r=json.load(sys.stdin); assert len(r)==1 and r[0]["gateway"]=="198.18.0.1" and r[0]["dev"]=="newordinary" and r[0]["metric"]==42760'\''
    grep -Fq "198.18.0.1" "$state"
    grep -Fq "newordinary" "$state"
    ! grep -Fq "oldordinary" "$state"
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config" remove >/dev/null
    test ! -e "$state"
  ' test-manage-vpn-bypass-routes.sh-link-change "$HELPER" "$CONFIG" "$STATE"; then
    fail "real link-disappearance migration regression failed"
  fi
  pass "real link disappearance reconciles route and existing state row to the new interface"
else
  printf 'ok - network namespace unavailable: %s\n' "$(tr '\n' ' ' <"$CASE_DIR/unshare-blocker.txt")"
fi

setup_case
printf '198.51.100.0/24\n' >"$CONFIG"
CONFIG2="$CASE_DIR/routes-second.conf"
printf '203.0.113.0/24\n' >"$CONFIG2"
if unshare -Urn --map-root-user true 2>"$CASE_DIR/unshare-blocker.txt"; then
  if ! unshare -Urn --map-root-user bash -eu -c '
    helper="$1"; config1="$2"; config2="$3"; state="$4"
    ip link add ordinary type dummy
    ip address add 192.0.2.2/24 dev ordinary
    ip link set ordinary up
    ip -4 route add default via 192.0.2.1 dev ordinary metric 100
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config1" apply >/dev/null &
    first=$!
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config2" apply >/dev/null &
    second=$!
    wait "$first"
    wait "$second"
    ip -j -4 route show table main exact 198.51.100.0/24 | python3 -c '\''import json,sys; assert len(json.load(sys.stdin))==1'\''
    ip -j -4 route show table main exact 203.0.113.0/24 | python3 -c '\''import json,sys; assert len(json.load(sys.stdin))==1'\''
    grep -Fq "198.51.100.0/24" "$state"
    grep -Fq "203.0.113.0/24" "$state"
    DOC_NEWBIE_TEST_HARNESS=1 DOC_NEWBIE_STATE_FILE="$state" "$helper" --config "$config1" remove >/dev/null
    test ! -e "$state"
  ' test-manage-vpn-bypass-routes.sh-concurrent "$HELPER" "$CONFIG" "$CONFIG2" "$STATE"; then
    fail "concurrent apply lost a route or state row"
  fi
  pass "concurrent applies serialize without losing routes or state rows"
else
  printf 'ok - network namespace unavailable: %s\n' "$(tr '\n' ' ' <"$CASE_DIR/unshare-blocker.txt")"
fi

printf '1..19\n'

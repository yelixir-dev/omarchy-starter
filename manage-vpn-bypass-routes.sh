#!/usr/bin/bash

set -euo pipefail

readonly DEFAULT_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/doc-newbie/vpn-bypass-routes.conf"
readonly DEFAULT_STATE="/run/doc-newbie/vpn-bypass-routes.state"
readonly STATE_HEADER="# doc-newbie vpn bypass routes state v2"
readonly ROUTE_METRIC="42760"
readonly TRUSTED_PATH="/usr/sbin:/usr/bin:/sbin:/bin"
readonly PYTHON_COMMAND="/usr/bin/python3"
readonly TIMEOUT_COMMAND="/usr/bin/timeout"

log() {
  printf '[vpn-bypass-routes] %s\n' "$*"
}

fail() {
  printf '[vpn-bypass-routes] 오류 / error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
사용법 / Usage:
  ./manage-vpn-bypass-routes.sh [--config PATH] validate|list|apply|remove|--help

VPN 기본 경로를 우회할 추가 IP/CIDR만 검증하고 관리합니다.
Tailscale 피어와 승인된 서브넷 경로는 tailscaled가 자동으로 관리하므로
설정 파일에 넣지 마세요. 이 도구는 Tailscale 밖의 추가 예외 전용입니다.

This helper manages only extra non-Tailscale IP/CIDR exceptions that should use
an ordinary non-VPN default route. Tailscale peer and accepted subnet routes are
automatic and must not be duplicated here.

명령 / Commands:
  validate  설정만 검증하고 경로는 변경하지 않습니다. / Validate only.
  list      정규화된 CIDR만 출력합니다. / List normalized CIDRs.
  apply     현재 일반 기본 경로로 추가·이전합니다(root 필요). / Reconcile to current defaults.
  remove    상태 파일로 입증된 정확한 경로만 제거합니다(root 필요). / Remove.

설정 / Config:
  기본값 / Default: ${XDG_CONFIG_HOME:-$HOME/.config}/doc-newbie/vpn-bypass-routes.conf
  빈 줄과 # 주석을 허용합니다. 나머지 각 줄은 정확한 IPv4/IPv6 CIDR 하나여야
  합니다. 호스트 이름, CIDR 없는 IP, 뒤쪽 텍스트와 셸 문법은 거부합니다.

상태 / State:
  /run/doc-newbie/ 아래 root 소유 파일에 family, CIDR, gateway, device와 전용
  metric을 기록합니다. apply 때마다 현재 일반 기본 경로를 다시 선택하며 상태의
  과거 gateway는 소유권 증명에만 씁니다. 관리되지 않은 형제 경로, Tailscale
  table 52와 tailscale0 경로는 교체하거나 삭제하지 않습니다.
EOF
}

is_unprivileged_test_namespace() {
  local inside="" outside="" length=""

  [[ -r /proc/self/uid_map ]] || return 1
  read -r inside outside length </proc/self/uid_map || return 1
  [[ "$inside" == "0" && "$outside" != "0" && "$length" == "1" ]]
}

is_test_harness() {
  local parent_command=""

  [[ "${DOC_NEWBIE_TEST_HARNESS:-}" == "1" && -r "/proc/$PPID/cmdline" ]] || return 1
  is_unprivileged_test_namespace || return 1
  parent_command="$(/usr/bin/tr '\0' ' ' <"/proc/$PPID/cmdline")"
  [[ "$parent_command" == *"test-manage-vpn-bypass-routes.sh"* ]]
}

TEST_MODE=false
STATE_FILE="$DEFAULT_STATE"
IP_COMMAND="/usr/bin/ip"
if is_test_harness; then
  TEST_MODE=true
  STATE_FILE="${DOC_NEWBIE_STATE_FILE:-$DEFAULT_STATE}"
  IP_COMMAND="${DOC_NEWBIE_TEST_IP:-$IP_COMMAND}"
fi
readonly TEST_MODE STATE_FILE IP_COMMAND
export PATH="$TRUSTED_PATH"

CONFIG_FILE="$DEFAULT_CONFIG"
action=""
while (( $# > 0 )); do
  case "$1" in
    --config)
      (( $# >= 2 )) || fail "--config 뒤에 경로가 필요합니다 / requires a path"
      CONFIG_FILE="$2"
      shift 2
      ;;
    -h | --help)
      [[ -z "$action" && $# -eq 1 ]] || fail "--help는 다른 명령과 함께 쓸 수 없습니다 / cannot be combined"
      usage
      exit 0
      ;;
    validate | list | apply | remove)
      [[ -z "$action" ]] || fail "명령은 하나만 지정하세요 / specify exactly one command"
      action="$1"
      shift
      ;;
    *)
      fail "지원하지 않는 인수입니다 / unsupported argument (use --help)"
      ;;
  esac
done
[[ -n "$action" ]] || fail "명령이 필요합니다 / command required (use --help)"
readonly CONFIG_FILE action

[[ -x "$PYTHON_COMMAND" ]] || fail "필요한 명령이 없습니다 / missing command: $PYTHON_COMMAND"
if [[ "$action" == "apply" || "$action" == "remove" ]]; then
  [[ -x "$IP_COMMAND" && -f "$IP_COMMAND" ]] || fail "필요한 ip 명령이 없습니다 / missing ip command"
  [[ -x "$TIMEOUT_COMMAND" ]] || fail "필요한 timeout 명령이 없습니다 / missing timeout command"
fi

run_ip() {
  "$TIMEOUT_COMMAND" --signal=TERM --kill-after=1s 10s "$IP_COMMAND" "$@"
}

declare -a TEMP_FILES=()
declare -a CHANGE_UNDO=()
declare -a CHANGE_FAMILY=()
declare -a CHANGE_CIDR=()
declare -a CHANGE_GATEWAY=()
declare -a CHANGE_INTERFACE=()
declare -a CHANGE_METRIC=()
OPERATION_ACTIVE=false
ROLLBACK_FAILED=false

change_route() {
  local operation="$1" family="$2" cidr="$3" gateway="$4" interface="$5" metric="$6"

  run_ip "-$family" route "$operation" "$cidr" via "$gateway" dev "$interface" \
    proto static metric "$metric"
}

route_identity_status() {
  local family="$1" cidr="$2" gateway="$3" interface="$4" metric="$5" json

  json="$(run_ip "-$family" -j route show table main exact "$cidr")" || return 2
  "$PYTHON_COMMAND" - "$family" "$cidr" "$gateway" "$interface" "$metric" "$json" <<'PYTHON_ROUTE'
import ipaddress
import json
import sys

family = int(sys.argv[1])
target = ipaddress.ip_network(sys.argv[2], strict=True)
expected_gateway = ipaddress.ip_address(sys.argv[3])
expected_device = sys.argv[4]
expected_metric = int(sys.argv[5])

try:
    routes = json.loads(sys.argv[6])
except (json.JSONDecodeError, UnicodeDecodeError):
    raise SystemExit(2)
if not isinstance(routes, list):
    raise SystemExit(2)
if not routes:
    print("absent")
    raise SystemExit(0)
if len(routes) != 1 or not isinstance(routes[0], dict):
    print("conflict")
    raise SystemExit(0)

route = routes[0]
try:
    destination = ipaddress.ip_network(route.get("dst", ""), strict=False)
    gateway = ipaddress.ip_address(route.get("gateway", ""))
except ValueError:
    print("conflict")
    raise SystemExit(0)

owned = (
    destination.version == family
    and destination == target
    and gateway.version == family
    and gateway == expected_gateway
    and route.get("dev") == expected_device
    and route.get("protocol") == "static"
    and route.get("metric") == expected_metric
)
print("owned" if owned else "conflict")
PYTHON_ROUTE
}

record_change() {
  CHANGE_UNDO+=("$1")
  CHANGE_FAMILY+=("$2")
  CHANGE_CIDR+=("$3")
  CHANGE_GATEWAY+=("$4")
  CHANGE_INTERFACE+=("$5")
  CHANGE_METRIC+=("$6")
}

rollback_changes() {
  local index undo family cidr gateway interface metric status

  ROLLBACK_FAILED=false
  for (( index=${#CHANGE_UNDO[@]}-1; index>=0; index-- )); do
    undo="${CHANGE_UNDO[index]}"
    family="${CHANGE_FAMILY[index]}"
    cidr="${CHANGE_CIDR[index]}"
    gateway="${CHANGE_GATEWAY[index]}"
    interface="${CHANGE_INTERFACE[index]}"
    metric="${CHANGE_METRIC[index]}"
    status="$(route_identity_status "$family" "$cidr" "$gateway" "$interface" "$metric" 2>/dev/null || true)"

    case "$undo:$status" in
      del:owned)
        change_route del "$family" "$cidr" "$gateway" "$interface" "$metric" >/dev/null 2>&1 || ROLLBACK_FAILED=true
        ;;
      del:absent | add:owned) ;;
      add:absent)
        change_route add "$family" "$cidr" "$gateway" "$interface" "$metric" >/dev/null 2>&1 || ROLLBACK_FAILED=true
        ;;
      *) ROLLBACK_FAILED=true ;;
    esac
  done
  $ROLLBACK_FAILED && printf '[vpn-bypass-routes] 오류 / error: 경로 롤백이 불완전합니다 / route rollback incomplete\n' >&2
  return 0
}

fail_transaction() {
  local message="$1"

  rollback_changes
  OPERATION_ACTIVE=false
  $ROLLBACK_FAILED && fail "$message; 롤백 불완전 / rollback incomplete"
  fail "$message; 이전 경로와 상태 보존 / prior routes and state preserved"
}

cleanup() {
  local status=$?
  local file

  set +e
  if $OPERATION_ACTIVE; then
    rollback_changes
    $ROLLBACK_FAILED && status=1
  fi
  for file in "${TEMP_FILES[@]}"; do
    [[ -n "$file" ]] && rm -f -- "$file"
  done
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

declare -a CONFIG_CIDRS=()
if [[ "$action" != "remove" ]]; then
  [[ -f "$CONFIG_FILE" && ! -L "$CONFIG_FILE" && -r "$CONFIG_FILE" ]] ||
    fail "읽을 수 있는 일반 설정 파일이 아닙니다 / config is not a readable regular file: $CONFIG_FILE"

  parser_output="$(mktemp "${TMPDIR:-/tmp}/vpn-bypass-routes.parse.XXXXXX")"
  TEMP_FILES+=("$parser_output")
  if ! "$PYTHON_COMMAND" - "$CONFIG_FILE" >"$parser_output" <<'PYTHON_CONFIG'
import ipaddress
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
try:
    text = path.read_bytes().decode("utf-8")
except (OSError, UnicodeDecodeError):
    print("설정을 UTF-8로 읽을 수 없습니다 / config is not readable UTF-8", file=sys.stderr)
    raise SystemExit(1)

networks = set()
for line_number, line in enumerate(text.splitlines(), 1):
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    if line != stripped or line.count("/") != 1 or not re.fullmatch(r"[0-9A-Fa-f:.]+/[0-9]+", line):
        print(f"잘못된 CIDR / invalid CIDR at line {line_number}", file=sys.stderr)
        raise SystemExit(1)
    try:
        network = ipaddress.ip_network(line, strict=True)
    except ValueError:
        print(f"잘못된 CIDR / invalid CIDR at line {line_number}", file=sys.stderr)
        raise SystemExit(1)
    networks.add(network)

for network in sorted(networks, key=lambda item: (item.version, int(item.network_address), item.prefixlen)):
    print(network.with_prefixlen)
PYTHON_CONFIG
  then
    fail "설정 검증 실패 / config validation failed"
  fi
  mapfile -t CONFIG_CIDRS <"$parser_output"
fi

if [[ "$action" == "validate" ]]; then
  log "유효한 설정 / valid configuration: ${#CONFIG_CIDRS[@]} unique CIDR(s)"
  exit 0
fi
if [[ "$action" == "list" ]]; then
  ((${#CONFIG_CIDRS[@]} == 0)) || printf '%s\n' "${CONFIG_CIDRS[@]}"
  exit 0
fi

(( EUID == 0 )) || fail "$action에는 유효 UID 0(root)이 필요합니다 / requires effective UID 0"

canonical_network() {
  "$PYTHON_COMMAND" - "$1" <<'PYTHON_NETWORK'
import ipaddress
import sys
try:
    value = ipaddress.ip_network(sys.argv[1], strict=True)
except ValueError:
    raise SystemExit(1)
print(value.with_prefixlen)
PYTHON_NETWORK
}

canonical_address() {
  "$PYTHON_COMMAND" - "$1" "$2" <<'PYTHON_ADDRESS'
import ipaddress
import sys
try:
    value = ipaddress.ip_address(sys.argv[1])
except ValueError:
    raise SystemExit(1)
if value.version != int(sys.argv[2]):
    raise SystemExit(1)
print(value.compressed)
PYTHON_ADDRESS
}

declare -a STATE_FAMILY=()
declare -a STATE_CIDR=()
declare -a STATE_GATEWAY=()
declare -a STATE_INTERFACE=()
declare -a STATE_METRIC=()
declare -A STATE_INDEX=()

check_state_permissions() {
  local owner mode

  [[ -e "$STATE_FILE" || -L "$STATE_FILE" ]] || return 0
  [[ -f "$STATE_FILE" && ! -L "$STATE_FILE" ]] || fail "상태 경로가 일반 파일이 아닙니다 / state path is not a regular file"
  owner="$(stat -c '%u' -- "$STATE_FILE")"
  mode="$(stat -c '%a' -- "$STATE_FILE")"
  [[ "$owner" == "0" ]] || fail "상태 파일이 root 소유가 아닙니다 / state file is not owned by root"
  (( (8#$mode & 8#022) == 0 )) || fail "상태 파일이 group/other 쓰기 가능합니다 / unsafe state permissions"
}

load_state() {
  local header="" line_number=1 family cidr gateway interface metric extra key canonical

  check_state_permissions
  [[ -e "$STATE_FILE" ]] || return 0
  exec 3<"$STATE_FILE"
  IFS= read -r header <&3 || true
  [[ "$header" == "$STATE_HEADER" ]] || fail "상태 파일 헤더가 잘못됐습니다 / invalid state header"

  while IFS=$'\t' read -r family cidr gateway interface metric extra <&3 ||
    [[ -n "$family$cidr$gateway$interface$metric${extra:-}" ]]; do
    line_number=$((line_number + 1))
    [[ -n "$family$cidr$gateway$interface$metric${extra:-}" ]] || continue
    [[ -z "${extra:-}" && ( "$family" == "4" || "$family" == "6" ) ]] ||
      fail "상태 파일 형식 오류 / malformed state at line $line_number"
    canonical="$(canonical_network "$cidr" 2>/dev/null || true)"
    [[ "$canonical" == "$cidr" ]] || fail "상태 CIDR 오류 / invalid state CIDR at line $line_number"
    if [[ "$family" == "4" ]]; then
      [[ "$cidr" != *:* ]] || fail "상태 family 불일치 / state family mismatch at line $line_number"
    else
      [[ "$cidr" == *:* ]] || fail "상태 family 불일치 / state family mismatch at line $line_number"
    fi
    canonical="$(canonical_address "$gateway" "$family" 2>/dev/null || true)"
    [[ "$canonical" == "$gateway" ]] || fail "상태 gateway 오류 / invalid state gateway at line $line_number"
    [[ "$interface" =~ ^[[:alnum:]_.:-]+$ ]] || fail "상태 interface 오류 / invalid state interface at line $line_number"
    case "$interface" in
      tailscale0 | tun* | tap* | wg* | nordlynx)
        fail "상태에 VPN interface가 있습니다 / VPN interface in state at line $line_number"
        ;;
    esac
    [[ "$metric" == "$ROUTE_METRIC" ]] || fail "상태 metric 오류 / invalid state metric at line $line_number"
    key="$family:$cidr"
    [[ -z "${STATE_INDEX[$key]+present}" ]] || fail "상태에 중복 경로가 있습니다 / duplicate state route"
    STATE_INDEX["$key"]="${#STATE_FAMILY[@]}"
    STATE_FAMILY+=("$family")
    STATE_CIDR+=("$cidr")
    STATE_GATEWAY+=("$gateway")
    STATE_INTERFACE+=("$interface")
    STATE_METRIC+=("$metric")
  done
  exec 3<&-
}

# apply/remove load state only after the exclusive operation lock is held,
# closing the stale-state race. validate/list do not need state.

find_ordinary_default() {
  local family="$1" json

  json="$(run_ip "-$family" -j route show table main default)" ||
    fail "IPv$family 기본 경로 확인 실패 / default route inspection failed"
  "$PYTHON_COMMAND" - "$family" "$json" <<'PYTHON_DEFAULT'
import ipaddress
import json
import re
import sys

family = int(sys.argv[1])
try:
    routes = json.loads(sys.argv[2])
except json.JSONDecodeError:
    raise SystemExit(2)
if not isinstance(routes, list):
    raise SystemExit(2)

candidates = []
for route in routes:
    if not isinstance(route, dict):
        raise SystemExit(2)
    if "multipath" in route or "nexthops" in route:
        print("unsupported multipath default", file=sys.stderr)
        raise SystemExit(2)
    if route.get("dst") != "default":
        continue
    gateway_text = route.get("gateway")
    device = route.get("dev")
    if not isinstance(gateway_text, str) or not isinstance(device, str):
        continue
    if device == "tailscale0" or re.match(r"^(tun|tap|wg)", device) or device == "nordlynx":
        continue
    if not re.fullmatch(r"[A-Za-z0-9_.:-]+", device):
        continue
    try:
        gateway = ipaddress.ip_address(gateway_text)
        metric = int(route.get("metric", 0))
    except (ValueError, TypeError):
        continue
    if gateway.version != family or metric < 0:
        continue
    candidates.append((metric, gateway.compressed, device))

if not candidates:
    raise SystemExit(1)
best_metric = min(item[0] for item in candidates)
best = sorted({(gateway, device) for metric, gateway, device in candidates if metric == best_metric})
if len(best) != 1:
    print("ambiguous equal-metric defaults", file=sys.stderr)
    raise SystemExit(2)
print(f"{best[0][0]}\t{best[0][1]}")
PYTHON_DEFAULT
}

network_destination() {
  "$PYTHON_COMMAND" - "$1" <<'PYTHON_DESTINATION'
import ipaddress
import sys
print(ipaddress.ip_network(sys.argv[1], strict=True).network_address.compressed)
PYTHON_DESTINATION
}

table_52_owns() {
  local family="$1" cidr="$2" output status

  set +e
  output="$(run_ip "-$family" route show table 52 2>/dev/null)"
  status=$?
  set -e
  (( status == 0 || status == 2 )) || fail "Tailscale table 52 확인 실패 / inspection failed"
  [[ -n "$output" ]] || return 1
  "$PYTHON_COMMAND" - "$cidr" "$output" <<'PYTHON_TABLE'
import ipaddress
import sys

target = ipaddress.ip_network(sys.argv[1], strict=True)
for line in sys.argv[2].splitlines():
    for token in line.split():
        if token == "default":
            raise SystemExit(0)
        try:
            route = ipaddress.ip_network(token, strict=False)
        except ValueError:
            continue
        if route.version == target.version and route.overlaps(target):
            raise SystemExit(0)
        break
raise SystemExit(1)
PYTHON_TABLE
}

ensure_not_tailscale_owned() {
  local family="$1" cidr="$2" destination lookup

  destination="$(network_destination "$cidr")"
  lookup="$(run_ip "-$family" route get "$destination" 2>/dev/null)" || fail "IPv$family 경로 조회 실패 / route lookup failed"
  [[ " $lookup " != *" dev tailscale0 "* ]] || fail "목적지가 tailscale0 소유입니다 / destination owned by tailscale0"
  ! table_52_owns "$family" "$cidr" || fail "목적지가 Tailscale table 52와 겹칩니다 / overlaps table 52"
}

ensure_state_directory() {
  local directory owner mode

  directory="$(dirname -- "$STATE_FILE")"
  if [[ ! -e "$directory" ]]; then
    if $TEST_MODE; then
      mkdir -p -- "$directory"
      chmod 700 -- "$directory"
    else
      install -d -m 700 -o root -g root -- "$directory"
    fi
  fi
  [[ -d "$directory" && ! -L "$directory" ]] || fail "상태 디렉터리가 안전하지 않습니다 / unsafe state directory"
  if ! $TEST_MODE; then
    owner="$(stat -c '%u' -- "$directory")"
    mode="$(stat -c '%a' -- "$directory")"
    [[ "$owner" == "0" && "$mode" == "700" ]] || fail "상태 디렉터리는 root:700이어야 합니다 / must be root-owned mode 700"
  fi
}

atomic_write_state() {
  local directory temporary row index
  local -a rows=()

  ensure_state_directory
  directory="$(dirname -- "$STATE_FILE")"
  temporary="$(mktemp "$directory/.vpn-bypass-routes.state.XXXXXX")"
  TEMP_FILES+=("$temporary")
  for (( index=0; index<${#STATE_FAMILY[@]}; index++ )); do
    printf -v row '%s\t%s\t%s\t%s\t%s' \
      "${STATE_FAMILY[index]}" "${STATE_CIDR[index]}" "${STATE_GATEWAY[index]}" \
      "${STATE_INTERFACE[index]}" "${STATE_METRIC[index]}"
    rows+=("$row")
  done
  {
    printf '%s\n' "$STATE_HEADER"
    ((${#rows[@]} == 0)) || printf '%s\n' "${rows[@]}" | LC_ALL=C sort
  } >"$temporary"
  chmod 600 -- "$temporary"
  $TEST_MODE || chown root:root -- "$temporary"

  trap '' INT TERM HUP
  if mv -f -- "$temporary" "$STATE_FILE"; then
    OPERATION_ACTIVE=false
    trap 'exit 130' INT TERM HUP
  else
    trap 'exit 130' INT TERM HUP
    return 1
  fi
}

atomic_remove_state() {
  trap '' INT TERM HUP
  if rm -f -- "$STATE_FILE"; then
    OPERATION_ACTIVE=false
    trap 'exit 130' INT TERM HUP
  else
    trap 'exit 130' INT TERM HUP
    return 1
  fi
}

acquire_operation_lock() {
  local lock_file

  ensure_state_directory
  lock_file="$(dirname -- "$STATE_FILE")/.vpn-bypass-routes.lock"
  exec {LOCK_FD}>"$lock_file" || fail "잠금 파일을 열 수 없습니다 / cannot open lock file"
  chmod 600 -- "$lock_file"
  $TEST_MODE || chown root:root -- "$lock_file"
  /usr/bin/flock -w 30 "$LOCK_FD" || fail "다른 apply/remove 작업이 진행 중입니다 / another apply/remove is in progress"
}

if [[ "$action" == "apply" || "$action" == "remove" ]]; then
  # Pre-lock safety check preserves precise symlink/owner/mode rejection order;
  # the authoritative load still happens only while the lock is held.
  check_state_permissions
  acquire_operation_lock
  load_state
fi

if [[ "$action" == "apply" ]]; then
  declare -A BASE_GATEWAY=()
  declare -A BASE_INTERFACE=()
  declare -a PLAN_MODE=()
  declare -a PLAN_FAMILY=()
  declare -a PLAN_CIDR=()
  declare -a PLAN_OLD_GATEWAY=()
  declare -a PLAN_OLD_INTERFACE=()
  declare -a PLAN_GATEWAY=()
  declare -a PLAN_INTERFACE=()

  # Current ordinary defaults are authoritative on every apply, including routes
  # already recorded in state. Discover every needed family before any mutation.
  for cidr in "${CONFIG_CIDRS[@]}"; do
    if [[ "$cidr" == *:* ]]; then family=6; else family=4; fi
    if [[ -z "${BASE_GATEWAY[$family]+present}" ]]; then
      default_spec="$(find_ordinary_default "$family" || true)"
      [[ -n "$default_spec" ]] || fail "사용 가능한 일반 IPv$family 기본 gateway/interface가 없습니다 / no ordinary default"
      IFS=$'\t' read -r BASE_GATEWAY["$family"] BASE_INTERFACE["$family"] <<<"$default_spec"
    fi
  done

  for cidr in "${CONFIG_CIDRS[@]}"; do
    if [[ "$cidr" == *:* ]]; then family=6; else family=4; fi
    ensure_not_tailscale_owned "$family" "$cidr"
    key="$family:$cidr"
    gateway="${BASE_GATEWAY[$family]}"
    interface="${BASE_INTERFACE[$family]}"
    old_gateway="$gateway"
    old_interface="$interface"
    mode="add"

    if [[ -n "${STATE_INDEX[$key]+present}" ]]; then
      state_index="${STATE_INDEX[$key]}"
      old_gateway="${STATE_GATEWAY[state_index]}"
      old_interface="${STATE_INTERFACE[state_index]}"
      status="$(route_identity_status "$family" "$cidr" "$old_gateway" "$old_interface" "$ROUTE_METRIC")" ||
        fail "현재 경로 확인 실패 / route inspection failed"
      case "$status" in
        absent) mode="add" ;;
        owned)
          if [[ "$old_gateway" == "$gateway" && "$old_interface" == "$interface" ]]; then
            mode="none"
          else
            mode="migrate"
          fi
          ;;
        *) fail "도구 상태와 현재 경로가 다르거나 형제 경로가 있습니다 / state mismatch or sibling route" ;;
      esac
    else
      status="$(route_identity_status "$family" "$cidr" "$gateway" "$interface" "$ROUTE_METRIC")" ||
        fail "현재 경로 확인 실패 / route inspection failed"
      [[ "$status" == "absent" ]] || fail "관리되지 않은 경로가 이미 있습니다 / unmanaged route already exists"
    fi

    [[ "$mode" != "none" ]] || continue
    PLAN_MODE+=("$mode")
    PLAN_FAMILY+=("$family")
    PLAN_CIDR+=("$cidr")
    PLAN_OLD_GATEWAY+=("$old_gateway")
    PLAN_OLD_INTERFACE+=("$old_interface")
    PLAN_GATEWAY+=("$gateway")
    PLAN_INTERFACE+=("$interface")
  done

  if ((${#PLAN_MODE[@]} == 0)); then
    log "모든 설정 경로가 현재 기본 경로로 적용됨 / all configured routes use current defaults"
    exit 0
  fi

  OPERATION_ACTIVE=true
  for (( index=0; index<${#PLAN_MODE[@]}; index++ )); do
    mode="${PLAN_MODE[index]}"
    family="${PLAN_FAMILY[index]}"
    cidr="${PLAN_CIDR[index]}"
    old_gateway="${PLAN_OLD_GATEWAY[index]}"
    old_interface="${PLAN_OLD_INTERFACE[index]}"
    gateway="${PLAN_GATEWAY[index]}"
    interface="${PLAN_INTERFACE[index]}"

    if [[ "$mode" == "migrate" ]]; then
      record_change add "$family" "$cidr" "$old_gateway" "$old_interface" "$ROUTE_METRIC"
      if ! change_route del "$family" "$cidr" "$old_gateway" "$old_interface" "$ROUTE_METRIC"; then
        fail_transaction "이전 경로 제거 실패 / old route removal failed"
      fi
    fi

    record_change del "$family" "$cidr" "$gateway" "$interface" "$ROUTE_METRIC"
    if ! change_route add "$family" "$cidr" "$gateway" "$interface" "$ROUTE_METRIC"; then
      fail_transaction "현재 기본 경로 설치 실패 / current-default route installation failed"
    fi

    key="$family:$cidr"
    if [[ -n "${STATE_INDEX[$key]+present}" ]]; then
      state_index="${STATE_INDEX[$key]}"
      STATE_GATEWAY[state_index]="$gateway"
      STATE_INTERFACE[state_index]="$interface"
    else
      STATE_INDEX["$key"]="${#STATE_FAMILY[@]}"
      STATE_FAMILY+=("$family")
      STATE_CIDR+=("$cidr")
      STATE_GATEWAY+=("$gateway")
      STATE_INTERFACE+=("$interface")
      STATE_METRIC+=("$ROUTE_METRIC")
    fi
  done
  atomic_write_state
  log "${#PLAN_MODE[@]}개 경로 조정 / reconciled ${#PLAN_MODE[@]} route(s) to current defaults"
  exit 0
fi

for (( index=0; index<${#STATE_FAMILY[@]}; index++ )); do
  family="${STATE_FAMILY[index]}"
  cidr="${STATE_CIDR[index]}"
  gateway="${STATE_GATEWAY[index]}"
  interface="${STATE_INTERFACE[index]}"
  metric="${STATE_METRIC[index]}"
  status="$(route_identity_status "$family" "$cidr" "$gateway" "$interface" "$metric")" || fail "기록 경로 확인 실패 / recorded route inspection failed"
  [[ "$status" == "absent" || "$status" == "owned" ]] || fail "형제/불일치 경로가 있어 제거하지 않습니다 / sibling or mismatched route"
done

if ((${#STATE_FAMILY[@]} == 0)); then
  [[ ! -e "$STATE_FILE" ]] || atomic_remove_state
  log "기록된 도구 소유 경로 없음 / no helper-owned routes recorded"
  exit 0
fi

OPERATION_ACTIVE=true
for (( index=0; index<${#STATE_FAMILY[@]}; index++ )); do
  family="${STATE_FAMILY[index]}"
  cidr="${STATE_CIDR[index]}"
  gateway="${STATE_GATEWAY[index]}"
  interface="${STATE_INTERFACE[index]}"
  metric="${STATE_METRIC[index]}"
  status="$(route_identity_status "$family" "$cidr" "$gateway" "$interface" "$metric")" || fail "제거 전 경로 확인 실패 / pre-remove inspection failed"
  [[ "$status" != "conflict" ]] || fail_transaction "제거 중 형제/불일치 경로 발견 / sibling or mismatch appeared during removal"
  [[ "$status" == "owned" ]] || continue
  record_change add "$family" "$cidr" "$gateway" "$interface" "$metric"
  if ! change_route del "$family" "$cidr" "$gateway" "$interface" "$metric"; then
    fail_transaction "경로 제거 실패 / route removal failed"
  fi
done
removed_count="${#CHANGE_UNDO[@]}"
atomic_remove_state
log "${removed_count}개 경로 제거 / removed ${removed_count} route(s)"

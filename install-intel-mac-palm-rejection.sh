#!/usr/bin/env bash

set -euo pipefail

readonly HWDB_FILE="/etc/udev/hwdb.d/70-apple-internal-touchpad.hwdb"
readonly MANAGED_MARKER="# Managed by doc-newbie install-intel-mac-palm-rejection.sh"

log() {
  printf '[intel-mac-palm-rejection] %s\n' "$*"
}

fail() {
  printf '[intel-mac-palm-rejection] 오류: %s\n' "$*" >&2
  exit 1
}

run_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo -- "$@"
  fi
}

is_managed_file() {
  local first_line=""

  [[ -f "$HWDB_FILE" ]] || return 1
  IFS= read -r first_line <"$HWDB_FILE" || true
  [[ "$first_line" == "$MANAGED_MARKER" ]]
}

usage() {
  cat <<'EOF'
사용법: ./install-intel-mac-palm-rejection.sh [옵션]

USB 장치로 잘못 분류된 Apple 내장 트랙패드를 internal로 바로잡아
libinput의 disable-while-typing 기능을 활성화합니다.

옵션:
  --dry-run    장치와 적용 내용을 확인하고 시스템은 변경하지 않습니다.
  --uninstall  이 스크립트가 만든 hwdb 설정을 제거합니다.
  -h, --help   이 도움말을 표시합니다.
EOF
}

mode="install"
case "${1:-}" in
  '')
    ;;
  --dry-run)
    mode="dry-run"
    ;;
  --uninstall)
    mode="uninstall"
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    fail "지원하지 않는 옵션입니다: $1 (--help로 사용법 확인)"
    ;;
esac

(( $# <= 1 )) || fail "인수는 하나만 사용할 수 있습니다."

for command in udevadm systemd-hwdb awk; do
  command -v "$command" >/dev/null 2>&1 ||
    fail "필요한 명령을 찾을 수 없습니다: $command"
done

if [[ "$mode" == "uninstall" ]]; then
  if [[ -e "$HWDB_FILE" ]] && ! is_managed_file; then
    fail "기존 $HWDB_FILE 파일은 이 스크립트가 만든 파일이 아니므로 삭제하지 않습니다."
  fi

  run_root rm -f -- "$HWDB_FILE"
  run_root systemd-hwdb update
  run_root udevadm trigger --subsystem-match=input --action=change
  run_root udevadm settle
  log "설정을 제거했습니다. 완전한 반영을 위해 로그아웃 후 다시 로그인하세요."
  exit 0
fi

command -v libinput >/dev/null 2>&1 ||
  fail "libinput-tools가 필요합니다: omarchy pkg add libinput-tools"

system_vendor=""
product_name=""
if [[ -r /sys/class/dmi/id/sys_vendor ]]; then
  IFS= read -r system_vendor </sys/class/dmi/id/sys_vendor
fi
if [[ -r /sys/class/dmi/id/product_name ]]; then
  IFS= read -r product_name </sys/class/dmi/id/product_name
fi

[[ "$system_vendor" == "Apple Inc." && "$product_name" == Mac* ]] ||
  fail "Apple MacBook 하드웨어가 아니므로 적용하지 않습니다."

declare -a candidate_devices=()
declare -a candidate_vendors=()
declare -a candidate_products=()
declare -a candidate_integrations=()
declare -a candidate_names=()

for device in /dev/input/event*; do
  is_touchpad=""
  device_vendor=""
  device_product=""
  device_integration=""
  device_name=""

  while IFS='=' read -r key value; do
    case "$key" in
      ID_INPUT_TOUCHPAD)
        is_touchpad="$value"
        ;;
      ID_VENDOR_ID)
        device_vendor="${value,,}"
        ;;
      ID_MODEL_ID)
        device_product="${value,,}"
        ;;
      ID_INPUT_TOUCHPAD_INTEGRATION)
        device_integration="$value"
        ;;
    esac
  done < <(udevadm info --query=property "$device" 2>/dev/null || true)

  name_file="/sys/class/input/${device##*/}/device/name"
  if [[ -r "$name_file" ]]; then
    IFS= read -r device_name <"$name_file"
  fi

  [[ "$is_touchpad" == "1" && "$device_vendor" == "05ac" ]] || continue
  case "$device_name" in
    *"Apple Internal Keyboard / Trackpad"* | *"Apple SPI Touchpad"* | bcm5974)
      ;;
    *)
      continue
      ;;
  esac

  candidate_devices+=("$device")
  candidate_vendors+=("$device_vendor")
  candidate_products+=("$device_product")
  candidate_integrations+=("${device_integration:-unknown}")
  candidate_names+=("$device_name")
done

(( ${#candidate_devices[@]} > 0 )) ||
  fail "Apple 내장 트랙패드를 찾지 못했습니다. 이 설정을 적용하지 않았습니다."
(( ${#candidate_devices[@]} == 1 )) ||
  fail "Apple 내장 트랙패드 후보가 여러 개라 안전하게 선택할 수 없습니다."

trackpad="${candidate_devices[0]}"
vendor="${candidate_vendors[0]}"
product="${candidate_products[0]}"
integration="${candidate_integrations[0]}"
device_name="${candidate_names[0]}"

[[ -n "$product" ]] ||
  fail "Apple 트랙패드의 USB 제품 ID를 확인하지 못했습니다."

log "모델: $product_name"
log "장치: $trackpad"
log "이름: $device_name"
log "USB ID: $vendor:$product"
log "현재 분류: $integration"

if [[ "$mode" == "dry-run" ]]; then
  printf '\n적용할 hwdb 항목:\n'
  printf 'touchpad:usb:v%sp%s:*\n' "$vendor" "$product"
  printf ' ID_INPUT_TOUCHPAD_INTEGRATION=internal\n'
  exit 0
fi

temporary_file="$(mktemp)"
trap 'rm -f -- "$temporary_file"' EXIT

if [[ -e "$HWDB_FILE" ]] && ! is_managed_file; then
  fail "기존 $HWDB_FILE 파일은 이 스크립트 소유가 아니므로 덮어쓰지 않습니다."
fi

{
  printf '%s\n' "$MANAGED_MARKER"
  printf '# Apple internal trackpad exposed through a virtual USB controller.\n'
  printf 'touchpad:usb:v%sp%s:*\n' "$vendor" "$product"
  printf ' ID_INPUT_TOUCHPAD_INTEGRATION=internal\n'
} >"$temporary_file"

log "내장 트랙패드 분류를 설치합니다."
run_root install -Dm644 "$temporary_file" "$HWDB_FILE"
run_root systemd-hwdb update
run_root udevadm trigger --subsystem-match=input --action=change
run_root udevadm settle

updated_integration="$(
  udevadm info --query=property "$trackpad" |
    awk -F= '$1 == "ID_INPUT_TOUCHPAD_INTEGRATION" { print $2; exit }'
)"

[[ "$updated_integration" == "internal" ]] ||
  fail "udev 분류가 internal로 바뀌지 않았습니다."

log "현재 udev 분류: $updated_integration"
printf '\n'
printf '설정은 설치됐습니다. 실행 중인 Hyprland가 장치를 다시 만들도록\n'
printf '로그아웃 후 다시 로그인하거나 재부팅하세요.\n'
printf '\n'
printf '다음 로그인 후 확인:\n'
printf '  libinput list-devices\n'
printf 'Apple 트랙패드 항목의 Disable-w-typing이 enabled여야 합니다.\n'

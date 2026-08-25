#!/usr/bin/env bash

set -euo pipefail

readonly PROFILE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5"
readonly PROFILE_FILE="$PROFILE_DIR/profile"
readonly ENVIRONMENT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
readonly ENVIRONMENT_FILE="$ENVIRONMENT_DIR/90-fcitx5.conf"
readonly DBUS_SERVICE="org.fcitx.Fcitx5"
readonly DBUS_PATH="/controller"
readonly DBUS_INTERFACE="org.fcitx.Fcitx.Controller1"

log() {
  printf '[fcitx5-hangul] %s\n' "$*"
}

fail() {
  printf '[fcitx5-hangul] 오류: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
사용법: ./install-fcitx5-hangul.sh

Arch Linux 또는 Omarchy에 Fcitx5 한글 입력기를 설치하고
영문 키보드와 한글 입력기를 기본 그룹에 등록합니다.

옵션:
  -h, --help  이 도움말을 표시합니다.
EOF
}

case "${1:-}" in
  '')
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

command -v pacman >/dev/null 2>&1 ||
  fail "이 스크립트는 Arch Linux 계열에서만 사용할 수 있습니다."

log "Fcitx5와 한글 엔진을 설치합니다."
if command -v omarchy >/dev/null 2>&1; then
  omarchy pkg add fcitx5 fcitx5-gtk fcitx5-qt fcitx5-hangul fcitx5-configtool
else
  sudo pacman -S --needed fcitx5 fcitx5-gtk fcitx5-qt fcitx5-hangul fcitx5-configtool
fi

mkdir -p "$PROFILE_DIR"
if [[ -f "$PROFILE_FILE" ]]; then
  backup="$(mktemp "${PROFILE_FILE}.bak.$(date +%Y%m%d-%H%M%S).XXXXXX")"
  cp --preserve=mode,timestamps -- "$PROFILE_FILE" "$backup"
  log "기존 프로필을 백업했습니다: $backup"
fi

if ! fcitx5-remote --check >/dev/null 2>&1; then
  log "Fcitx5를 시작합니다."
  fcitx5 --disable notificationitem -d
fi

for _ in {1..50}; do
  if fcitx5-remote --check >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

fcitx5-remote --check >/dev/null 2>&1 ||
  fail "Fcitx5가 시작되지 않았습니다. 로그아웃 후 다시 로그인한 다음 재실행하세요."

log "영문 키보드와 한글 입력기를 기본 그룹에 등록합니다."
busctl --user call \
  "$DBUS_SERVICE" \
  "$DBUS_PATH" \
  "$DBUS_INTERFACE" \
  SetInputMethodGroupInfo \
  'ssa(ss)' \
  Default \
  us \
  2 \
  keyboard-us \
  '' \
  hangul \
  ''

busctl --user call \
  "$DBUS_SERVICE" \
  "$DBUS_PATH" \
  "$DBUS_INTERFACE" \
  Save

if ! busctl --user call \
  "$DBUS_SERVICE" \
  "$DBUS_PATH" \
  "$DBUS_INTERFACE" \
  FullInputMethodGroupInfo \
  s \
  Default | LC_ALL=C awk 'index($0, "\"hangul\"") { found=1 } END { exit !found }'
then
  fail "한글 입력기 등록을 확인하지 못했습니다."
fi

if [[ "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
  mkdir -p "$ENVIRONMENT_DIR"
  if [[ -f "$ENVIRONMENT_FILE" ]]; then
    environment_backup="$(
      mktemp "${ENVIRONMENT_FILE}.bak.$(date +%Y%m%d-%H%M%S).XXXXXX"
    )"
    cp --preserve=mode,timestamps -- "$ENVIRONMENT_FILE" "$environment_backup"
    log "기존 X11 환경 파일을 백업했습니다: $environment_backup"
  fi
  {
    printf 'GTK_IM_MODULE=fcitx\n'
    printf 'QT_IM_MODULE=fcitx\n'
    printf 'XMODIFIERS=@im=fcitx\n'
    printf 'SDL_IM_MODULE=fcitx\n'
  } >"$ENVIRONMENT_FILE"
  log "X11 입력기 환경을 저장했습니다: $ENVIRONMENT_FILE"
fi

log "설정이 끝났습니다."
printf '\n'
printf '기본 한/영 전환: Ctrl + Space\n'
printf '확인 방법: 메모장이나 터미널에서 gksrmf을 입력해 "한글"로 조합되는지 확인하세요.\n'
printf '기존 Fcitx 단축키를 바꾼 적이 있다면 fcitx5-configtool에서 전환키를 확인하세요.\n'
printf '일부 앱 또는 X11에서 바로 동작하지 않으면 로그아웃 후 다시 로그인하세요.\n'

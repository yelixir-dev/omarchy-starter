#!/usr/bin/env bash
# 이미 설치된 Bottles 카카오톡의 한글 입력창이 네모로 보일 때 사용합니다.

set -euo pipefail

readonly BOTTLE_NAME="kakaotalk"
readonly FLATPAK_ID="com.usebottles.bottles"
readonly FONT_PACKAGE="ttf-baekmuk"
readonly FONT_SOURCE_DIR="${KAKAOTALK_FONT_SOURCE_DIR:-/usr/share/fonts/TTF}"
readonly BOTTLE_ROOT="${KAKAOTALK_BOTTLE_ROOT:-$HOME/.var/app/$FLATPAK_ID/data/bottles/bottles/$BOTTLE_NAME}"
readonly DRIVE_C="$BOTTLE_ROOT/drive_c"
readonly FONTS_DIR="$DRIVE_C/windows/Fonts"
readonly REG_FILE="$DRIVE_C/fix-korean-input.reg"
readonly NOISE_PATTERN='HTTP 403|Catalog (components|installers|dependencies) loaded|wineserver: using server-side synchronization|Windows path detected|Avoiding validation'

log() {
  printf '[kakaotalk-font-patch] %s\n' "$*"
}

fail() {
  printf '[kakaotalk-font-patch] 오류: %s\n' "$*" >&2
  exit 1
}

run_quiet() {
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  printf '%s\n' "$out" |
    /usr/bin/grep -vE "$NOISE_PATTERN" |
    /usr/bin/grep -v '^[[:space:]]*$' || true
  return "$rc"
}

bottles_cli() {
  run_quiet flatpak run --command=bottles-cli "$FLATPAK_ID" "$@"
}

install_font_package() {
  if pacman -Q "$FONT_PACKAGE" >/dev/null 2>&1; then
    return
  fi

  log "한글 TrueType 글꼴을 설치합니다. 관리자 암호를 입력하세요."
  sudo pacman -S --needed --noconfirm "$FONT_PACKAGE"
}

check_environment() {
  command -v flatpak >/dev/null 2>&1 ||
    fail "Flatpak이 없습니다. 먼저 Bottles를 설치하세요."
  flatpak info "$FLATPAK_ID" >/dev/null 2>&1 ||
    fail "Bottles Flatpak이 없습니다. 먼저 카카오톡 설치 스크립트를 실행하세요."
  [[ -d "$FONTS_DIR" ]] ||
    fail "kakaotalk 보틀의 Windows Fonts 폴더를 찾지 못했습니다: $FONTS_DIR"
}

copy_fonts() {
  local name
  for name in batang dotum gulim; do
    [[ -f "$FONT_SOURCE_DIR/$name.ttf" ]] ||
      fail "글꼴 파일이 없습니다: $FONT_SOURCE_DIR/$name.ttf"
    install -m 0644 "$FONT_SOURCE_DIR/$name.ttf" "$FONTS_DIR/$name.ttf"
  done
}

write_registry_patch() {
  cat >"$REG_FILE" <<'REG'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Fonts]
"Baekmuk Batang (TrueType)"="batang.ttf"
"Baekmuk Dotum (TrueType)"="dotum.ttf"
"Baekmuk Gulim (TrueType)"="gulim.ttf"

[HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements]
"Batang"="Baekmuk Batang"
"Dotum"="Baekmuk Dotum"
"Gulim"="Baekmuk Gulim"
"GulimChe"="Baekmuk Gulim"
"Malgun Gothic"="Baekmuk Gulim"
"Malgun Gothic Bold"="Baekmuk Gulim"

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]
"Batang"="Baekmuk Batang"
"Dotum"="Baekmuk Dotum"
"Gulim"="Baekmuk Gulim"
"GulimChe"="Baekmuk Gulim"
"Malgun Gothic"="Baekmuk Gulim"
"Malgun Gothic Bold"="Baekmuk Gulim"
REG
}

add_localized_aliases() {
  local key='HKEY_CURRENT_USER\Software\Wine\Fonts\Replacements'

  bottles_cli reg add -b "$BOTTLE_NAME" -k "$key" -v '맑은 고딕' -d 'Baekmuk Gulim' -t REG_SZ
  bottles_cli reg add -b "$BOTTLE_NAME" -k "$key" -v '굴림' -d 'Baekmuk Gulim' -t REG_SZ
  bottles_cli reg add -b "$BOTTLE_NAME" -k "$key" -v '돋움' -d 'Baekmuk Dotum' -t REG_SZ
  bottles_cli reg add -b "$BOTTLE_NAME" -k "$key" -v '바탕' -d 'Baekmuk Batang' -t REG_SZ
}

apply_patch() {
  check_environment
  install_font_package
  copy_fonts
  write_registry_patch
  bottles_cli run -b "$BOTTLE_NAME" -e 'C:\windows\regedit.exe' '/S' 'C:\fix-korean-input.reg'
  add_localized_aliases
  log "한글 입력 글꼴 패치를 적용했습니다."
}

usage() {
  cat <<'EOF'
사용법:
  ./patch-kakaotalk-korean-input.sh

카카오톡 채팅 입력창의 한글이 네모로 보일 때 실행합니다.
적용 후 카카오톡을 완전히 종료했다가 다시 실행하세요.
EOF
}

case "${1:-}" in
  "")
    apply_patch
    log "카카오톡을 완전히 종료했다가 다시 실행하세요."
    ;;
  --from-installer)
    apply_patch
    ;;
  -h|--help)
    usage
    ;;
  *)
    fail "지원하지 않는 인수입니다: $1"
    ;;
esac

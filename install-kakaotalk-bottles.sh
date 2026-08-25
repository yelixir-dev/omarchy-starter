#!/usr/bin/bash
# Bottles(Flatpak)로 카카오톡 Windows 버전을 설치합니다.
# Super + Shift + K가 비어 있으면 카카오톡 실행 단축키도 등록합니다.
#
# 사용법:
#   ./install-kakaotalk-bottles.sh             설치(또는 이어서 진행)
#   ./install-kakaotalk-bottles.sh --uninstall 제거
#
# 준비: 설치 도중 카카오톡 설치 관리자(Windows GUI)가 열리면
# 사용자가 직접 "다음"을 눌러 설치를 완료해야 합니다.

set -euo pipefail

readonly BOTTLE_NAME="kakaotalk"
readonly FLATPAK_ID="com.usebottles.bottles"
readonly DOWNLOAD_PAGE="https://www.kakaocorp.com/page/service/all"
readonly BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"

log() { printf '[kakaotalk-bottles] %s\n' "$*"; }
fail() { printf '[kakaotalk-bottles] 오류: %s\n' "$*" >&2; exit 1; }

# 초보자가 불안해할 필요가 없는 알려진 잡음(Flatpak 경고, 403 인덱스,
# wineserver 동기화 메시지)만 걸러냅니다. 실제 오류와 종료 코드는 유지합니다.
NOISE_PATTERN='XDG_DATA_DIRS|are not in the search path|applications installed by Flatpak|HTTP 403|Catalog (components|installers|dependencies) loaded|wineserver: using server-side synchronization|^Note that the directories|^$\x27/var/lib/flatpak|^$\x27/home/'

run_quiet() {
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  printf '%s\n' "$out" | /usr/bin/grep -vE "$NOISE_PATTERN" | /usr/bin/grep -v '^[[:space:]]*$' || true
  return "$rc"
}

bottles_cli() {
  run_quiet flatpak run --command=bottles-cli "$FLATPAK_ID" "$@"
}

have_bottles() {
  command -v flatpak >/dev/null 2>&1 && flatpak info "$FLATPAK_ID" >/dev/null 2>&1
}

# Bottles Flatpak은 기본적으로 홈 폴더 접근이 막혀 있을 수 있어
# 설치 파일(~/Downloads)과 보틀 디렉터리 접근 권한을 부여합니다.
grant_flatpak_access() {
  flatpak override --user "$FLATPAK_ID" --filesystem=home
  log "Flatpak 홈 폴더 접근 권한을 부여했습니다"
}

install_bottles() {
  log "Bottles(Flatpak)를 설치합니다. 관리자 암호를 입력하세요."
  sudo pacman -S --needed --noconfirm flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub "$FLATPAK_ID"
}

bottle_drive_c() {
  printf '%s' "$HOME/.var/app/$FLATPAK_ID/data/bottles/bottles/$BOTTLE_NAME/drive_c"
}

# Windows 환경에 한글 폰트가 없으면 설치 관리자와 앱 글자가 네모로 깨집니다.
# 시스템의 Noto CJK 폰트를 보틀에 넣고 맑은 고딕 등을 대체 등록합니다.
install_korean_fonts() {
  local drive_c fonts_dir reg_file src
  drive_c="$(bottle_drive_c)"
  fonts_dir="$drive_c/windows/Fonts"
  [[ -d "$fonts_dir" ]] || return 0

  for src in /usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc /usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc; do
    [[ -f "$src" ]] && cp -n "$src" "$fonts_dir/"
  done

  reg_file="$drive_c/fixfonts.reg"
  cat >"$reg_file" <<'REG'
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]
"Malgun Gothic"="Noto Sans CJK KR"
"Malgun Gothic Bold"="Noto Sans CJK KR"
"Gulim"="Noto Sans CJK KR"
"GulimChe"="Noto Sans CJK KR"
"Dotum"="Noto Sans CJK KR"
"Batang"="Noto Sans CJK KR"
REG
  run_quiet bottles_cli_direct run -b "$BOTTLE_NAME" -e 'C:\windows\regedit.exe' '/S' 'C:\fixfonts.reg' >/dev/null || true

  # 모니터 배율이 2인 환경에서 Wine 기본 96 DPI는 글자가 너무 작습니다.
  # 레지스트리 v5 형식이어야 적용됩니다(REGEDIT4는 조용히 무시됨).
  cat >"$drive_c/dpi.reg" <<'REG'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Control Panel\Desktop]
"LogPixels"=dword:000000c0
REG
  run_quiet bottles_cli_direct run -b "$BOTTLE_NAME" -e 'C:\windows\regedit.exe' '/S' 'C:\dpi.reg' >/dev/null || true
  log "보틀에 한글 폰트·대체 등록·200% DPI를 적용했습니다"
}

bottles_cli_direct() {
  flatpak run --command=bottles-cli "$FLATPAK_ID" "$@"
}

find_installer() {
  local candidate
  for candidate in "$HOME/Downloads/"*[Kk]akao[Tt]alk*[Ss]etup*.exe "$HOME/Downloads/"*KakaoTalk*.exe; do
    [[ -f "$candidate" ]] && { printf '%s' "$candidate"; return 0; }
  done
  return 1
}

ensure_installer() {
  local installer
  if installer="$(find_installer)"; then
    printf '%s' "$installer"
    return 0
  fi
  log "카카오톡 Windows 설치 파일이 ~/Downloads에 없습니다."
  log "브라우저에서 공식 페이지를 엽니다: $DOWNLOAD_PAGE"
  log "'PC버전 다운로드(Windows)'를 받은 뒤 이 스크립트를 다시 실행하세요."
  xdg-open "$DOWNLOAD_PAGE" >/dev/null 2>&1 || true
  exit 2
}

bottle_exists() {
  bottles_cli info -b "$BOTTLE_NAME" >/dev/null 2>&1
}

kakaotalk_exe_path() {
  local base="$HOME/.local/share/bottles/bottles/$BOTTLE_NAME/drive_c"
  local p
  for p in \
    "$base/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe" \
    "$base/Program Files/Kakao/KakaoTalk/KakaoTalk.exe"; do
    [[ -f "$p" ]] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

binding_exists() {
  grep -q 'SUPER + SHIFT + K' "$BINDINGS_FILE" 2>/dev/null
}

binding_free() {
  # modmask 65 = SUPER+SHIFT
  ! hyprctl binds -j 2>/dev/null | jq -e '.[] | select(.modmask == 65 and .key == "K")' >/dev/null 2>&1
}

add_binding() {
  if binding_exists; then
    log "단축키가 이미 설정 파일에 있습니다: 건너뜀"
    return 0
  fi
  if ! binding_free; then
    log "Super + Shift + K가 이미 다른 동작에 할당돼 있어 단축키를 등록하지 않습니다."
    log "바꾸고 싶으면 $BINDINGS_FILE 을 직접 편집하세요."
    return 0
  fi
  cat >>"$BINDINGS_FILE" <<'EOF'

-- KakaoTalk (Bottles)
o.bind("SUPER + SHIFT + K", "KakaoTalk", "flatpak run --command=bottles-cli com.usebottles.bottles run -b kakaotalk -p KakaoTalk")
EOF
  hyprctl reload >/dev/null 2>&1 || true
  log "Super + Shift + K 단축키를 등록했습니다"
}

case "${1:-install}" in
  install)
    have_bottles || install_bottles
    have_bottles || fail "Bottles 설치에 실패했습니다"
    grant_flatpak_access

    installer="$(ensure_installer)"
    log "설치 파일: $installer"
    [[ -r "$installer" ]] || fail "설치 파일을 읽을 수 없습니다: $installer"

    if ! bottle_exists; then
      log "kakaotalk 보틀을 생성합니다(처음은 몇 분 걸립니다)"
      bottles_cli new --bottle-name "$BOTTLE_NAME" --environment application
    else
      log "kakaotalk 보틀이 이미 있습니다"
    fi

    install_korean_fonts

    if ! kakaotalk_exe_path >/dev/null 2>&1; then
      log "잠시 뒤 카카오톡 설치 관리자(Windows 창)가 열립니다."
      log "설치를 끝까지 완료한 뒤 이 터미널로 돌아와 Enter를 누르세요."
      bottles_cli run -b "$BOTTLE_NAME" -e "$installer" &
      run_pid=$!
      read -r -p "설치 관리자에서 설치를 완료했으면 Enter를 누르세요: "
      wait "$run_pid" 2>/dev/null || true
    fi

    exe="$(kakaotalk_exe_path)" || fail "KakaoTalk.exe를 찾지 못했습니다. 설치 관리자에서 설치가 완료됐는지 확인하세요."
    log "KakaoTalk.exe 확인: $exe"

    win_path="${exe#*/drive_c/}"
    win_path="C:\\${win_path//\//\\}"
    if ! bottles_cli programs -b "$BOTTLE_NAME" 2>/dev/null | grep -qi 'KakaoTalk'; then
      bottles_cli add -b "$BOTTLE_NAME" -n "KakaoTalk" -p "$win_path" ||
        log "프로그램 등록은 건너뛰었습니다(실행에는 지장 없음)"
    fi

    add_binding

    log "완료: Super + Shift + K 또는 Bottles에서 카카오톡을 실행하세요"
    ;;
  --uninstall)
    if have_bottles && bottle_exists; then
      bottles_cli delete -b "$BOTTLE_NAME" || fail "보틀 삭제 실패"
    fi
    if [[ -f "$BINDINGS_FILE" ]] && binding_exists; then
      cp "$BINDINGS_FILE" "$BINDINGS_FILE.bak-$(date +%Y%m%d-%H%M%S)"
      sed -i '/-- KakaoTalk (Bottles)/,+1d' "$BINDINGS_FILE"
      hyprctl reload >/dev/null 2>&1 || true
    fi
    log "제거 완료(Flatpak Bottles 자체는 남겨둡니다)"
    ;;
  *)
    fail "지원하지 않는 인수입니다: $1 (install | --uninstall)"
    ;;
esac

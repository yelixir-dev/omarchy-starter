#!/usr/bin/bash
# Mac 스타일 스크린샷 단축키와 상태바 캡처 버튼을 설치/제거합니다.
#   Super + Shift + 9 : 영역 캡처 (Mac의 Cmd+Shift+4)
#   Super + Shift + 0 : 전체 화면 캡처 (Mac의 Cmd+Shift+3)
# 두 기능 모두 ~/Pictures에 저장하고 클립보드에도 복사합니다.
# 상태바에는 카페인(인디케이터)과 시계 사이에 항상 보이는 치카라 버튼을 둡니다.
# sudo 없이 사용자 설정만 변경합니다.
#
# 사용법:
#   ./install-screenshot-shortcuts.sh             설치(또는 갱신)
#   ./install-screenshot-shortcuts.sh --uninstall 제거

set -euo pipefail

readonly PLUGIN_ID="user.capture-button"
readonly PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
readonly SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
readonly BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
readonly RESTART_SHELL="/usr/share/omarchy/bin/omarchy-restart-shell"

log() { printf '[screenshot-shortcuts] %s\n' "$*"; }
fail() { printf '[screenshot-shortcuts] 오류: %s\n' "$*" >&2; exit 1; }

write_plugin() {
  mkdir -p -- "$PLUGIN_DIR"
  cat >"$PLUGIN_DIR/manifest.json" <<'EOF'
{
  "schemaVersion": 1,
  "id": "user.capture-button",
  "name": "Screenshot",
  "version": "1.0.0",
  "author": "user",
  "description": "Always-visible bar button that captures the full screen to Pictures and clipboard",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "CaptureButton.qml" },
  "barWidget": {
    "displayName": "Screenshot",
    "description": "Full-screen capture button",
    "category": "System",
    "allowMultiple": false
  }
}
EOF
  cat >"$PLUGIN_DIR/CaptureButton.qml" <<'EOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "user.capture-button"

  function capture() { if (!captureProc.running) captureProc.running = true }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: captureProc
    command: ["/usr/share/omarchy/bin/omarchy-capture-screenshot", "fullscreen", "slurp"]
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf030"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "전체 화면 캡처 (그림 폴더와 클립보드에 저장)"
    keepSpace: true
    useActiveColor: false
    active: true
    onPressed: root.capture()
  }
}
EOF
}

add_bindings() {
  [[ -f "$BINDINGS_FILE" ]] || fail "bindings.lua가 없습니다: $BINDINGS_FILE"
  if grep -q 'SUPER + SHIFT + 9' "$BINDINGS_FILE"; then
    log "스크린샷 단축키가 이미 등록돼 있습니다: 건너뜀"
    return 0
  fi
  cp "$BINDINGS_FILE" "$BINDINGS_FILE.bak-$(date +%Y%m%d-%H%M%S)"
  cat >>"$BINDINGS_FILE" <<'EOF'

-- Mac-style screenshots: Super+Shift+9 area, Super+Shift+0 fullscreen
-- Both save to ~/Pictures and copy to the clipboard.
o.bind("SUPER + SHIFT + 9", "Screenshot: 영역 캡처", "omarchy-capture-screenshot region slurp")
o.bind("SUPER + SHIFT + 0", "Screenshot: 전체 화면 캡처", "omarchy-capture-screenshot fullscreen slurp")
EOF
  log "Super + Shift + 9 / 0 단축키를 등록했습니다"
}

remove_bindings() {
  [[ -f "$BINDINGS_FILE" ]] || return 0
  grep -q 'SUPER + SHIFT + 9' "$BINDINGS_FILE" || return 0
  cp "$BINDINGS_FILE" "$BINDINGS_FILE.bak-$(date +%Y%m%d-%H%M%S)"
  sed -i '/-- Mac-style screenshots/,+3d' "$BINDINGS_FILE"
  log "단축키를 제거했습니다"
}

update_layout() {
  local mode="$1"
  [[ -f "$SHELL_JSON" ]] || fail "shell.json이 없습니다: $SHELL_JSON"
  PI_PLUGIN_ID="$PLUGIN_ID" PI_MODE="$mode" /usr/bin/python3 - "$SHELL_JSON" <<'PYEOF'
import json, os, sys

path = sys.argv[1]
plugin_id = os.environ["PI_PLUGIN_ID"]
mode = os.environ["PI_MODE"]

with open(path, encoding="utf-8") as fh:
    data = json.load(fh)

layout = data["bar"]["layout"]
cleaned, seen = [], set()
for widget in layout.get("center", []):
    wid = widget.get("id", "")
    if wid == plugin_id or wid in seen:
        continue
    seen.add(wid)
    cleaned.append(widget)

if mode == "install":
    out = []
    placed = False
    for widget in cleaned:
        out.append(widget)
        if widget.get("id") == "omarchy.indicators" and not placed:
            out.append({"id": plugin_id})
            placed = True
    if not placed:
        out.insert(0, {"id": plugin_id})
    layout["center"] = out
else:
    layout["center"] = cleaned

layout["right"] = [w for w in layout.get("right", []) if w.get("id") != plugin_id]

with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PYEOF
}

restart_all() {
  hyprctl reload >/dev/null 2>&1 || true
  [[ -x "$RESTART_SHELL" ]] && "$RESTART_SHELL" >/dev/null
  log "Hyprland와 셀을 다시 읽었습니다"
}

case "${1:-install}" in
  install)
    command -v omarchy >/dev/null || fail "omarchy 명령이 없습니다."
    [[ -x /usr/share/omarchy/bin/omarchy-capture-screenshot ]] || fail "omarchy-capture-screenshot이 없습니다."
    write_plugin
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    omarchy plugin enable "$PLUGIN_ID" >/dev/null
    add_bindings
    update_layout install
    restart_all
    log "완료: Super+Shift+9 영역, Super+Shift+0 전체 화면, 바 치카라 버튼 사용 가능"
    ;;
  --uninstall)
    omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
    rm -rf -- "$PLUGIN_DIR"
    remove_bindings
    update_layout uninstall
    restart_all
    log "제거 완료"
    ;;
  *)
    fail "지원하지 않는 인수입니다: $1 (install | --uninstall)"
    ;;
esac

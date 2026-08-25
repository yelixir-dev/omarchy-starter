#!/usr/bin/bash
# Fcitx5 입력 언어 표시 위젯을 Omarchy 상태바에 설치/제거합니다.
# 오른쪽 시스템 아이콘 줄 맨 앞에 K(한국어)/E(English)를 표시하고,
# 클릭하면 한/영이 전환됩니다. sudo 없이 사용자 설정만 변경합니다.
#
# 사용법:
#   ./install-fcitx5-bar-indicator.sh             설치(또는 갱신)
#   ./install-fcitx5-bar-indicator.sh --uninstall 제거

set -euo pipefail

readonly PLUGIN_ID="user.fcitx-state"
readonly PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
readonly SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
readonly RESTART_SHELL="/usr/share/omarchy/bin/omarchy-restart-shell"

log() { printf '[fcitx5-bar-indicator] %s\n' "$*"; }
fail() { printf '[fcitx5-bar-indicator] 오류: %s\n' "$*" >&2; exit 1; }

write_manifest() {
  cat >"$PLUGIN_DIR/manifest.json" <<'EOF'
{
  "schemaVersion": 1,
  "id": "user.fcitx-state",
  "name": "Input language",
  "version": "1.0.0",
  "author": "user",
  "description": "Shows current Fcitx5 input language (Korean/English); click toggles",
  "kinds": [
    "bar-widget"
  ],
  "entryPoints": {
    "barWidget": "FcitxState.qml"
  },
  "barWidget": {
    "displayName": "Input language",
    "description": "Fcitx5 Korean/English state indicator",
    "category": "System",
    "allowMultiple": false
  }
}
EOF
}

write_qml() {
  cat >"$PLUGIN_DIR/FcitxState.qml" <<'EOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "user.fcitx-state"

  property bool korean: false

  function refresh() {
    if (!checkProc.running) checkProc.running = true
  }

  function toggle() {
    if (!toggleProc.running) toggleProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: checkProc
    command: ["/usr/bin/fcitx5-remote", "-n"]
    stdout: StdioCollector {
      onStreamFinished: function() {
        root.korean = this.text.trim() === "hangul"
      }
    }
  }

  Process {
    id: toggleProc
    command: ["/usr/bin/fcitx5-remote", "-t"]
    onExited: function(exitCode) {
      refreshTimer.restart()
    }
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshTimer
    interval: 300
    repeat: false
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.korean ? "K" : "E"
    slotSize: Style.bar.statusSlot
    fontSize: Style.bar.iconFont
    tooltipText: root.korean ? "입력 언어: 한국어 (클릭하면 영어)" : "입력 언어: English (클릭하면 한국어)"
    keepSpace: true
    useActiveColor: false
    onPressed: root.toggle()
  }
}
EOF
}

update_layout() {
  local mode="$1"
  [[ -f "$SHELL_JSON" ]] || fail "shell.json이 없습니다: $SHELL_JSON (Omarchy shell을 한 번 실행한 뒤 다시 시도하세요)"
  PI_PLUGIN_ID="$PLUGIN_ID" PI_MODE="$mode" /usr/bin/python3 - "$SHELL_JSON" <<'PYEOF'
import json, os, sys

path = sys.argv[1]
plugin_id = os.environ["PI_PLUGIN_ID"]
mode = os.environ["PI_MODE"]

with open(path, encoding="utf-8") as fh:
    data = json.load(fh)

layout = data["bar"]["layout"]["right"]
cleaned, seen = [], set()
for widget in layout:
    wid = widget.get("id", "")
    if wid == plugin_id or wid in seen:
        continue
    seen.add(wid)
    cleaned.append(widget)

if mode == "install":
    cleaned.insert(0, {"id": plugin_id})

data["bar"]["layout"]["right"] = cleaned

# plugin enable이 중앙 레이아웃에도 자동 추가하므로 항상 제거한다
center = data["bar"]["layout"].get("center", [])
data["bar"]["layout"]["center"] = [w for w in center if w.get("id") != plugin_id]
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PYEOF
}

restart_shell() {
  [[ -x "$RESTART_SHELL" ]] || fail "셀 재시작 명령이 없습니다: $RESTART_SHELL"
  "$RESTART_SHELL" >/dev/null
  log "셀을 재시작했습니다"
}

case "${1:-install}" in
  install)
    command -v fcitx5-remote >/dev/null || fail "fcitx5-remote가 없습니다. 먼저 Fcitx5를 설치하세요."
    command -v omarchy >/dev/null || fail "omarchy 명령이 없습니다."
    mkdir -p -- "$PLUGIN_DIR"
    write_manifest
    write_qml
    # 방금 만든 사용자 플러그인을 셀이 인식하도록 재스캔(없는 환경에서는 무시)
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    omarchy plugin enable "$PLUGIN_ID" >/dev/null
    update_layout install
    restart_shell
    log "설치 완료: 상태바 오른쪽에 K(한국어)/E(English)가 표시됩니다"
    ;;
  --uninstall)
    omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
    [[ -f "$SHELL_JSON" ]] && update_layout uninstall
    rm -rf -- "$PLUGIN_DIR"
    restart_shell
    log "제거 완료"
    ;;
  *)
    fail "지원하지 않는 인수입니다: $1 (install | --uninstall)"
    ;;
esac

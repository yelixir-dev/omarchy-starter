#!/usr/bin/bash
# Tailscale/NordVPN 상태바 토글 아이콘을 설치/제거합니다.
# 설치된 것만 표시합니다: Tailscale이 있으면 Tailscale 아이콘,
# NetworkManager VPN 프로필이 있으면 NordVPN 아이콘을 추가합니다.
# sudo 없이 사용자 설정만 변경합니다(Tailscale 토글의 무암호 동작은
# sudo tailscale set --operator="$USER" 를 한 번 실행해야 합니다).
#
# 사용법:
#   ./install-vpn-bar-toggles.sh             설치(또는 갱신)
#   ./install-vpn-bar-toggles.sh --uninstall 제거

set -euo pipefail

readonly PLUGINS_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
readonly SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
readonly RESTART_SHELL="/usr/share/omarchy/bin/omarchy-restart-shell"
readonly TS_ID="user.tailscale-toggle"
readonly NV_ID="user.nordvpn-toggle"

log() { printf '[vpn-bar-toggles] %s\n' "$*"; }
fail() { printf '[vpn-bar-toggles] 오류: %s\n' "$*" >&2; exit 1; }

has_tailscale() { command -v tailscale >/dev/null 2>&1; }

find_vpn_uuid() {
  /usr/bin/nmcli -t -f UUID,TYPE connection show 2>/dev/null |
    /usr/bin/awk -F: '$2 == "vpn" { print $1; exit }'
}

write_ts_plugin() {
  local dir="$PLUGINS_ROOT/$TS_ID"
  mkdir -p -- "$dir"
  cat >"$dir/manifest.json" <<'EOF'
{
  "schemaVersion": 1,
  "id": "user.tailscale-toggle",
  "name": "Tailscale toggle",
  "version": "1.0.0",
  "author": "user",
  "description": "Bar icon showing Tailscale state; click toggles tailscale up/down",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "TailscaleToggle.qml" },
  "barWidget": {
    "displayName": "Tailscale",
    "description": "Tailscale on/off toggle",
    "category": "System",
    "allowMultiple": false
  }
}
EOF
  cat >"$dir/TailscaleToggle.qml" <<'EOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "user.tailscale-toggle"

  property bool tailscaleUp: false

  function refresh() { if (!checkProc.running) checkProc.running = true }
  function toggle() { if (!toggleProc.running) toggleProc.running = true }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: checkProc
    command: ["/usr/bin/bash", "-c", "/usr/bin/tailscale status --json 2>/dev/null | /usr/bin/jq -r .BackendState"]
    stdout: StdioCollector {
      onStreamFinished: function() { root.tailscaleUp = this.text.trim() === "Running" }
    }
  }

  Process {
    id: toggleProc
    command: root.tailscaleUp
      ? ["/usr/bin/tailscale", "down"]
      : ["/usr/bin/tailscale", "up", "--accept-routes=false"]
    onExited: function(exitCode) { refreshTimer.restart() }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshTimer
    interval: 1000
    repeat: false
    onTriggered: root.refresh()
  }

  HoverHandler { id: hover }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf0c1"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: root.tailscaleUp ? "Tailscale: 켜짐 (클릭하면 끔)" : "Tailscale: 꺼짐 (클릭하면 켬)"
    keepSpace: true
    useActiveColor: false
    active: root.tailscaleUp
    dimmed: !root.tailscaleUp && hover.hovered
    concealed: !root.tailscaleUp && !hover.hovered
    interactive: root.tailscaleUp || hover.hovered
    onPressed: root.toggle()
  }
}
EOF
}

write_nv_plugin() {
  local dir="$PLUGINS_ROOT/$NV_ID" uuid="$1"
  mkdir -p -- "$dir"
  cat >"$dir/manifest.json" <<'EOF'
{
  "schemaVersion": 1,
  "id": "user.nordvpn-toggle",
  "name": "NordVPN toggle",
  "version": "1.0.0",
  "author": "user",
  "description": "Bar icon showing VPN state; click toggles the NetworkManager profile",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "NordvpnToggle.qml" },
  "barWidget": {
    "displayName": "NordVPN",
    "description": "NordVPN on/off toggle",
    "category": "System",
    "allowMultiple": false
  }
}
EOF
  cat >"$dir/NordvpnToggle.qml" <<EOF
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "user.nordvpn-toggle"

  property bool vpnUp: false

  function refresh() { if (!checkProc.running) checkProc.running = true }
  function toggle() { if (!toggleProc.running) toggleProc.running = true }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: checkProc
    command: ["/usr/bin/bash", "-c", "/usr/bin/nmcli -t -f UUID connection show --active 2>/dev/null | /usr/bin/grep -c '^${uuid}\$' || true"]
    stdout: StdioCollector {
      onStreamFinished: function() { root.vpnUp = this.text.trim() === "1" }
    }
  }

  Process {
    id: toggleProc
    command: root.vpnUp
      ? ["/usr/bin/nmcli", "--wait", "25", "connection", "down", "uuid", "${uuid}"]
      : ["/usr/bin/nmcli", "connection", "up", "uuid", "${uuid}"]
    onExited: function(exitCode) { refreshTimer.restart() }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshTimer
    interval: 1000
    repeat: false
    onTriggered: root.refresh()
  }

  HoverHandler { id: hover }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf132"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: root.vpnUp ? "NordVPN: 켜짐 (클릭하면 끔)" : "NordVPN: 꺼짐 (클릭하면 켬)"
    keepSpace: true
    useActiveColor: false
    active: root.vpnUp
    dimmed: !root.vpnUp && hover.hovered
    concealed: !root.vpnUp && !hover.hovered
    interactive: root.vpnUp || hover.hovered
    onPressed: root.toggle()
  }
}
EOF
}

remove_plugin() {
  local id="$1"
  omarchy plugin disable "$id" >/dev/null 2>&1 || true
  rm -rf -- "$PLUGINS_ROOT/$id"
}

update_layout() {
  local ts_flag="$1" nv_flag="$2"
  [[ -f "$SHELL_JSON" ]] || fail "shell.json이 없습니다: $SHELL_JSON"
  PI_TS_ID="$TS_ID" PI_NV_ID="$NV_ID" PI_TS_FLAG="$ts_flag" PI_NV_FLAG="$nv_flag" \
    /usr/bin/python3 - "$SHELL_JSON" <<'PYEOF'
import json, os, sys

path = sys.argv[1]
ts_id, nv_id = os.environ["PI_TS_ID"], os.environ["PI_NV_ID"]
want_ts = os.environ["PI_TS_FLAG"] == "1"
want_nv = os.environ["PI_NV_FLAG"] == "1"

with open(path, encoding="utf-8") as fh:
    data = json.load(fh)

layout = data["bar"]["layout"]
cleaned, seen = [], set()
for widget in layout.get("center", []):
    wid = widget.get("id", "")
    if wid in (ts_id, nv_id) or wid in seen:
        continue
    seen.add(wid)
    cleaned.append(widget)

insertions = []
if want_ts:
    insertions.append({"id": ts_id})
if want_nv:
    insertions.append({"id": nv_id})

result = []
placed = False
for widget in cleaned:
    result.append(widget)
    if widget.get("id") == "omarchy.weather" and not placed:
        result.extend(insertions)
        placed = True
if not placed:
    result.extend(insertions)

layout["center"] = result
layout["right"] = [w for w in layout.get("right", []) if w.get("id") not in (ts_id, nv_id)]

with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PYEOF
}

restart_shell() {
  [[ -x "$RESTART_SHELL" ]] || fail "셸 재시작 명령이 없습니다: $RESTART_SHELL"
  "$RESTART_SHELL" >/dev/null
  log "셸을 재시작했습니다"
}

case "${1:-install}" in
  install)
    command -v omarchy >/dev/null || fail "omarchy 명령이 없습니다."
    ts_ok=false; nv_ok=false; vpn_uuid=""
    has_tailscale && ts_ok=true
    vpn_uuid="$(find_vpn_uuid || true)"
    [[ -n "$vpn_uuid" ]] && nv_ok=true

    if ! $ts_ok && ! $nv_ok; then
      fail "Tailscale도 NetworkManager VPN 프로필도 없습니다. 먼저 하나를 설치하세요."
    fi

    if $ts_ok; then
      write_ts_plugin
      log "Tailscale 감지: 링크 아이콘 추가"
    else
      remove_plugin "$TS_ID"
      log "Tailscale 없음: 해당 아이콘은 추가하지 않습니다"
    fi

    if $nv_ok; then
      write_nv_plugin "$vpn_uuid"
      log "VPN 프로필 감지($vpn_uuid): 방패 아이콘 추가"
    else
      remove_plugin "$NV_ID"
      log "VPN 프로필 없음: 해당 아이콘은 추가하지 않습니다"
    fi

    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    $ts_ok && omarchy plugin enable "$TS_ID" >/dev/null
    $nv_ok && omarchy plugin enable "$NV_ID" >/dev/null

    update_layout "$($ts_ok && echo 1 || echo 0)" "$($nv_ok && echo 1 || echo 0)"
    restart_shell
    log "완료: 켜진 아이콘만 보이고, 꺼진 아이콘은 마우스를 올리면 나타납니다"
    ;;
  --uninstall)
    remove_plugin "$TS_ID"
    remove_plugin "$NV_ID"
    update_layout 0 0
    restart_shell
    log "제거 완료"
    ;;
  *)
    fail "지원하지 않는 인수입니다: $1 (install | --uninstall)"
    ;;
esac

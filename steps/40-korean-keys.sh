register_step korean-keys recommended yes no

KEYS_LUA="$OS_CONFIG_DIR/hypr/korean-keys.lua"
KEYS_HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
KEYS_FCITX="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/config"

korean_keys_choices() {
  printf '%s\n' keep-ctrl-space ralt-only
}

korean_keys_status() {
  block_present "$KEYS_HYPR" korean-keys -- && [[ -f "$KEYS_LUA" ]] && echo installed || echo missing
}

korean_keys_lua() {
  cat <<'LUA'
local current = hl.get_config("input.kb_options") or ""
if not current:find("korean:ralt_hangul", 1, true) then
  local joined = current ~= "" and (current .. ",korean:ralt_hangul") or "korean:ralt_hangul"
  hl.config({ input = { kb_options = joined } })
end

hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Omarchy menu", "fcitx5-remote -c; omarchy-menu toggle")
LUA
}

korean_keys_fcitx_restart() {
  if systemctl --user cat omarchy-fcitx5.service >/dev/null 2>&1; then
    systemctl --user "$1" omarchy-fcitx5.service
  fi
}

korean_keys_set_trigger_hangul_only() {
  local tmp
  korean_keys_fcitx_restart stop
  mkdir -p -- "$(dirname -- "$KEYS_FCITX")"
  if [[ -f "$KEYS_FCITX" ]]; then
    state_set korean-keys.fcitx-backup "$(backup_file "$KEYS_FCITX")"
  else
    state_set korean-keys.fcitx-backup none
  fi
  touch -- "$KEYS_FCITX"
  tmp="$(mktemp)"
  awk '
    /^\[Hotkey\/TriggerKeys\]$/ { skip = 1; next }
    /^\[/ { skip = 0 }
    !skip { print }
  ' "$KEYS_FCITX" >"$tmp"
  printf '[Hotkey/TriggerKeys]\n0=Hangul\n' >>"$tmp"
  cat "$tmp" >"$KEYS_FCITX"
  rm -f -- "$tmp"
  korean_keys_fcitx_restart start
}

korean_keys_install() {
  mkdir -p -- "$(dirname -- "$KEYS_LUA")"
  korean_keys_lua >"$KEYS_LUA"
  if has_cmd luac; then
    luac -p "$KEYS_LUA"
  fi
  [[ -f "$KEYS_HYPR" ]] || die "$(t korean-keys.no_hypr): $KEYS_HYPR"
  backup_file "$KEYS_HYPR" >/dev/null
  block_write "$KEYS_HYPR" korean-keys "dofile(\"$KEYS_LUA\")" --
  if [[ "${STEP_CHOICE:-keep-ctrl-space}" == ralt-only ]]; then
    korean_keys_set_trigger_hangul_only
  fi
  has_cmd hyprctl && hyprctl reload >/dev/null 2>&1 || true
  log "$(t korean-keys.done)"
}

korean_keys_remove() {
  local backup
  block_remove "$KEYS_HYPR" korean-keys --
  rm -f -- "$KEYS_LUA"
  backup="$(state_get korean-keys.fcitx-backup || true)"
  if [[ -n "$backup" ]]; then
    korean_keys_fcitx_restart stop
    if [[ "$backup" == none ]]; then
      rm -f -- "$KEYS_FCITX"
    elif [[ -f "$backup" ]]; then
      cp -- "$backup" "$KEYS_FCITX"
    fi
    state_del korean-keys.fcitx-backup
    korean_keys_fcitx_restart start
  fi
  has_cmd hyprctl && hyprctl reload >/dev/null 2>&1 || true
}

register_step omo recommended yes no

OMO_BUN_BIN="$HOME/.bun/bin"

omo_bin() {
  if [[ -x "$OMO_BUN_BIN/omo" ]]; then
    printf '%s' "$OMO_BUN_BIN/omo"
  else
    command -v omo
  fi
}

omo_status() {
  local bin current latest
  bin="$(omo_bin)" || { echo missing; return; }
  current="$("$bin" --version 2>/dev/null | awk '{print $2}')"
  latest="$(curl -fsS --max-time 3 https://registry.npmjs.org/omo-ai/latest 2>/dev/null |
    sed -n 's/.*"version":"\([^"]*\)".*/\1/p')"
  if [[ -n "$latest" && -n "$current" && "$current" != "$latest" ]]; then
    echo outdated
  else
    echo installed
  fi
}

omo_install() {
  export PATH="$OMO_BUN_BIN:$HOME/.local/share/mise/shims:$PATH"
  if ! has_cmd bun; then
    is_omarchy || die "$(t omo.need_bun)"
    omarchy install dev-env bun
    hash -r
  fi
  has_cmd node || die "$(t omo.need_node)"
  block_write "$HOME/.bashrc" bun-path 'export PATH="$HOME/.bun/bin:$PATH"'
  bun i -g omo-ai
  "$OMO_BUN_BIN/omo" --version
  log "$(t omo.done)"
}

omo_remove() {
  export PATH="$OMO_BUN_BIN:$HOME/.local/share/mise/shims:$PATH"
  if [[ -x "$OMO_BUN_BIN/omo" ]] && has_cmd bun; then
    bun remove -g omo-ai
  else
    warn "$(t omo.not_bun)"
  fi
  block_remove "$HOME/.bashrc" bun-path
}

register_step nano required yes yes

NANO_EDITOR_FILE="$HOME/.local/state/omarchy/defaults/editor"

nano_status() {
  pkg_present nano || { echo missing; return; }
  [[ -f "$NANO_EDITOR_FILE" && "$(<"$NANO_EDITOR_FILE")" == nano ]] && echo installed || echo missing
}

nano_install() {
  if ! pkg_present nano; then
    pkg_add nano
    state_set nano.package ours
  fi
  if [[ -f "$NANO_EDITOR_FILE" && "$(<"$NANO_EDITOR_FILE")" != nano ]]; then
    state_set nano.previous "$(<"$NANO_EDITOR_FILE")"
  fi
  mkdir -p -- "$(dirname -- "$NANO_EDITOR_FILE")"
  printf 'nano\n' >"$NANO_EDITOR_FILE"
  log "$(t nano.done)"
}

nano_remove() {
  local previous
  previous="$(state_get nano.previous || true)"
  if [[ -n "$previous" ]]; then
    printf '%s\n' "$previous" >"$NANO_EDITOR_FILE"
  else
    rm -f -- "$NANO_EDITOR_FILE"
  fi
  state_del nano.previous
  if [[ "$(state_get nano.package || true)" == ours ]]; then
    pkg_drop nano
    state_del nano.package
  fi
}

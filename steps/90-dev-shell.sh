register_step dev-shell optional yes yes

DEV_SHELL_RC="$OS_CONFIG_DIR/bash/dev-shell.sh"
DEV_SHELL_LAZYGIT="${XDG_CONFIG_HOME:-$HOME/.config}/lazygit/config.yml"

dev_shell_status() {
  block_present "$HOME/.bashrc" dev-shell && [[ -f "$DEV_SHELL_RC" ]] && echo installed || echo missing
}

dev_shell_rc() {
  cat <<'RC'
__omarchy_starter_history() {
  local picked
  picked="$(HISTTIMEFORMAT='' history | sed 's/^ *[0-9]* *//' | tac | awk '!seen[$0]++' |
    fzf --height 40% --reverse --query "$READLINE_LINE")" || return
  READLINE_LINE="$picked"
  READLINE_POINT=${#picked}
}
[[ $- == *i* ]] && bind -x '"\er": __omarchy_starter_history'
alias md='glow'
RC
}

dev_shell_git_set() {
  local key="$1" value="$2" previous
  previous="$(git config --global --get "$key" || true)"
  state_set "dev-shell.git.$key" "${previous:-<unset>}"
  git config --global "$key" "$value"
}

dev_shell_git_restore() {
  local key="$1" previous
  previous="$(state_get "dev-shell.git.$key" || true)"
  [[ -z "$previous" ]] && return 0
  if [[ "$previous" == "<unset>" ]]; then
    git config --global --unset "$key" || true
  else
    git config --global "$key" "$previous"
  fi
  state_del "dev-shell.git.$key"
}

dev_shell_install() {
  pkg_add git-delta glow fzf lazygit
  mkdir -p -- "$(dirname -- "$DEV_SHELL_RC")"
  dev_shell_rc >"$DEV_SHELL_RC"
  block_write "$HOME/.bashrc" dev-shell "[[ -f \"$DEV_SHELL_RC\" ]] && source \"$DEV_SHELL_RC\""
  dev_shell_git_set core.pager delta
  dev_shell_git_set interactive.diffFilter 'delta --color-only'
  dev_shell_git_set delta.navigate true
  mkdir -p -- "$(dirname -- "$DEV_SHELL_LAZYGIT")"
  touch -- "$DEV_SHELL_LAZYGIT"
  if [[ -s "$DEV_SHELL_LAZYGIT" ]] && ! block_present "$DEV_SHELL_LAZYGIT" dev-shell; then
    warn "$(t dev-shell.lazygit_skip): $DEV_SHELL_LAZYGIT"
  else
    block_write "$DEV_SHELL_LAZYGIT" dev-shell 'git:
  paging:
    colorArg: always
    pager: delta --paging=never'
  fi
  log "$(t dev-shell.done)"
}

dev_shell_remove() {
  block_remove "$HOME/.bashrc" dev-shell
  rm -f -- "$DEV_SHELL_RC"
  block_remove "$DEV_SHELL_LAZYGIT" dev-shell
  dev_shell_git_restore core.pager
  dev_shell_git_restore interactive.diffFilter
  dev_shell_git_restore delta.navigate
}

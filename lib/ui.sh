#!/usr/bin/env bash
# Four-state checklist on /dev/tty: [v] install, [-] keep, [x] remove, [ ] skip.

ui_marker() {
  case "$1" in
    install) printf '[v]' ;;
    keep) printf '[-]' ;;
    remove) printf '[x]' ;;
    *) printf '[ ]' ;;
  esac
}

ui_cycle() {
  local id="$1" now="${ACTION[$1]}"
  if [[ "${STATUS[$id]}" == missing ]]; then
    [[ "$now" == install ]] && ACTION[$id]=none || ACTION[$id]=install
    return
  fi
  case "$now" in
    keep) ACTION[$id]=install ;;
    install)
      if [[ "${REMOVABLE[$id]}" == yes ]]; then ACTION[$id]=remove; else ACTION[$id]=keep; fi
      ;;
    *) ACTION[$id]=keep ;;
  esac
}

ui_color() {
  [[ -n "${NO_COLOR:-}" ]] && return 0
  case "$1" in
    reset) printf '\e[0m' ;;
    bold) printf '\e[1m' ;;
    dim) printf '\e[2m' ;;
    accent) printf '\e[38;5;179m' ;;
    install) printf '\e[38;5;114m' ;;
    remove) printf '\e[38;5;167m' ;;
    keep) printf '\e[38;5;110m' ;;
    rule) printf '\e[38;5;240m' ;;
  esac
}

ui_status_label() {
  local id="$1" s="${STATUS[$1]}"
  if [[ -n "${T[$id.status.$s]+set}" ]]; then
    t "$id.status.$s"
  else
    t "status.$s"
  fi
}

ui_status_width() {
  local w=0 s id
  for id in "${ROWS[@]}"; do
    s="$(str_width "$(ui_status_label "$id")")"
    ((s > w)) && w=$s
  done
  printf '%s' $((w + 2))
}

ui_line() {
  local n="$1" line
  ((n > 0)) || return 0
  printf -v line '%*s' "$n" ''
  printf '%s' "${line// /─}"
}

ui_rule() {
  local label="$1" cols="$2" used
  used=$(( $(str_width "$label") + 4 ))
  ui_color rule
  printf ' ── '
  ui_color reset
  ui_color bold
  printf '%s ' "$label"
  ui_color reset
  ui_color rule
  ui_line $((cols > used + 1 ? cols - used - 1 : 0))
  ui_color reset
  printf '\n'
}

ui_row() {
  local id="$1" selected="$2" sw="$3" action="${ACTION[$1]}"
  if ((selected)); then
    ui_color accent
    printf ' > '
  else
    printf '   '
  fi
  ui_color "$action"
  ui_marker "$action"
  ui_color reset
  printf ' '
  ui_color dim
  pad_to "$(ui_status_label "$id")" "$sw"
  ui_color reset
  ((selected)) && ui_color bold
  printf '%s' "$(t "$id.name")"
  [[ -n "$(declare -F "${id//-/_}_choices")" ]] && printf ' ▸'
  ui_color reset
  printf '\n'
}

ui_desc_lines() {
  local id="$1" line
  while IFS= read -r line; do
    printf '   %s\n' "$line"
  done <<<"$(t "$id.desc")"
  if [[ -n "${T[$id.changes]+set}" ]]; then
    printf '   '
    ui_color dim
    printf '%s %s' "$(t ui.changes)" "$(t "$id.changes")"
    ui_color reset
    printf '\n'
  fi
}

ui_render() {
  local cursor="$1" cols lines sw i id cat last="" desc_n header_n=4 avail top
  cols="$(tput cols 2>/dev/null || echo 80)"
  lines="$(tput lines 2>/dev/null || echo 24)"
  sw="$(ui_status_width)"
  local -a desc
  mapfile -t desc < <(ui_desc_lines "${ROWS[$cursor]}")
  desc_n=$(( ${#desc[@]} + 2 ))
  avail=$(( lines - header_n - desc_n - 1 ))
  ((avail < 5)) && avail=5
  top=0
  local visual=$(( cursor + 3 ))
  ((visual >= avail)) && top=$(( visual - avail + 1 ))

  printf '\e[H\e[2J'
  ui_color accent
  printf ' %s' "$(t ui.title)"
  ui_color reset
  printf '\n'
  ui_color dim
  printf ' %s\n' "$(t ui.keys)"
  ui_color reset
  printf ' '
  for i in install keep remove none; do
    ui_color "$i"
    ui_marker "$i"
    ui_color reset
    printf ' %s  ' "$(t "legend.$i")"
  done
  printf '\n\n'

  local n=0 printed=0
  for i in "${!ROWS[@]}"; do
    id="${ROWS[$i]}"
    cat="${CAT[$id]}"
    if [[ "$cat" != "$last" ]]; then
      if ((n >= top && printed < avail)); then
        ui_rule "$(t "cat.$cat")" "$cols"
        printed=$((printed + 1))
      fi
      n=$((n + 1))
      last="$cat"
    fi
    if ((n >= top && printed < avail)); then
      ui_row "$id" $((i == cursor)) "$sw"
      printed=$((printed + 1))
    fi
    n=$((n + 1))
  done

  ui_color rule
  printf ' '
  ui_line $((cols > 2 ? cols - 2 : 1))
  printf '\n'
  ui_color reset
  ui_color bold
  printf ' %s\n' "$(t "${ROWS[$cursor]}.name")"
  ui_color reset
  printf '%s\n' "${desc[@]}"
}

ui_read_key() {
  local key rest
  IFS= read -rsn1 key <&"$UI_IN" || return 1
  if [[ "$key" == $'\e' ]]; then
    IFS= read -rsn2 -t 0.05 rest <&"$UI_IN" || true
    case "$rest" in
      '[A' | 'OA') key=up ;;
      '[B' | 'OB') key=down ;;
      *) key=esc ;;
    esac
  fi
  case "$key" in
    '') printf 'enter' ;;
    ' ') printf 'space' ;;
    k) printf 'up' ;;
    j) printf 'down' ;;
    *) printf '%s' "$key" ;;
  esac
}

ui_enter() {
  exec {UI_OUT}>/dev/tty
  exec {UI_IN}</dev/tty
  printf '\e[?1049h\e[?25l' >&"$UI_OUT"
  UI_ACTIVE=1
}

ui_leave() {
  ((${UI_ACTIVE:-0})) || return 0
  printf '\e[?25h\e[?1049l' >&"$UI_OUT"
  UI_ACTIVE=0
}

ui_checklist() {
  local cursor=0 key
  ui_enter
  trap 'ui_leave' EXIT
  trap 'ui_leave; exit 130' INT TERM
  while true; do
    ui_render "$cursor" >&"$UI_OUT"
    key="$(ui_read_key)" || { ui_leave; return 1; }
    case "$key" in
      up) ((cursor > 0)) && cursor=$((cursor - 1)) ;;
      down) ((cursor < ${#ROWS[@]} - 1)) && cursor=$((cursor + 1)) ;;
      space) ui_cycle "${ROWS[$cursor]}" ;;
      a) apply_default_actions ;;
      enter) ui_leave; return 0 ;;
      q | esc) ui_leave; return 1 ;;
    esac
  done
}

ui_select_one() {
  # ui_select_one <title> <default-index> <key> <label> [<key> <label> ...]
  local title="$1" cursor="$2" key i
  shift 2
  local -a keys=() labels=()
  while (($#)); do
    keys+=("$1")
    labels+=("$2")
    shift 2
  done
  ui_enter
  while true; do
    {
      printf '\e[H\e[2J'
      ui_color accent
      printf ' %s\n' "$title"
      ui_color reset
      ui_color dim
      printf ' %s\n\n' "$(t ui.keys_one)"
      ui_color reset
      for i in "${!keys[@]}"; do
        if ((i == cursor)); then
          ui_color accent
          printf ' > (•) '
          ui_color bold
        else
          printf '   ( ) '
        fi
        printf '%s' "${labels[$i]}"
        ui_color reset
        printf '\n'
      done
    } >&"$UI_OUT"
    key="$(ui_read_key)" || { ui_leave; return 1; }
    case "$key" in
      up) ((cursor > 0)) && cursor=$((cursor - 1)) ;;
      down) ((cursor < ${#keys[@]} - 1)) && cursor=$((cursor + 1)) ;;
      enter | space) ui_leave; printf '%s' "${keys[$cursor]}"; return 0 ;;
      q | esc) ui_leave; return 1 ;;
    esac
  done
}

ui_confirm() {
  local prompt="$1" answer
  printf '%s [y/N] ' "$prompt" >/dev/tty
  IFS= read -r answer </dev/tty || return 1
  [[ "$answer" == [yY]* ]]
}

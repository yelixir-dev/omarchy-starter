#!/usr/bin/env bash

OS_STATE_DIR="${OMARCHY_STARTER_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-starter}"
OS_CONFIG_DIR="${OMARCHY_STARTER_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-starter}"

os_marker_begin() { printf '%s >>> omarchy-starter %s >>>' "${2:-#}" "$1"; }
os_marker_end() { printf '%s <<< omarchy-starter %s <<<' "${2:-#}" "$1"; }

t() {
  local key="$1"
  if [[ -n "${T[$key]+set}" ]]; then
    printf '%s' "${T[$key]}"
  else
    printf '%s' "$key"
  fi
}

log() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() {
  printf '[x] %s\n' "$*" >&2
  exit 1
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

is_omarchy() { has_cmd omarchy; }

pkg_present() {
  pacman -Q "$@" >/dev/null 2>&1
}

pkg_add() {
  if is_omarchy; then
    omarchy pkg add "$@"
  else
    sudo pacman -S --needed --noconfirm "$@"
  fi
}

pkg_aur_add() {
  if is_omarchy; then
    omarchy pkg aur add "$@"
  elif has_cmd yay; then
    yay -S --needed --noconfirm "$@"
  else
    die "AUR helper not found (omarchy pkg aur add / yay)"
  fi
}

pkg_drop() {
  local installed=() p
  for p in "$@"; do
    pkg_present "$p" && installed+=("$p")
  done
  ((${#installed[@]})) || return 0
  if is_omarchy; then
    omarchy pkg drop "${installed[@]}"
  else
    sudo pacman -Rns --noconfirm "${installed[@]}"
  fi
}

is_intel_mac() {
  local vendor=""
  [[ -r /sys/class/dmi/id/sys_vendor ]] && vendor="$(</sys/class/dmi/id/sys_vendor)"
  [[ "$vendor" == Apple* ]] && grep -q 'GenuineIntel' /proc/cpuinfo 2>/dev/null
}

backup_file() {
  local file="$1" backup
  [[ -f "$file" ]] || return 0
  backup="$file.bak-omarchy-starter-$(date +%Y%m%d-%H%M%S)"
  cp --preserve=mode,timestamps -- "$file" "$backup"
  printf '%s\n' "$backup"
}

block_present() {
  local file="$1" id="$2" prefix="${3:-#}"
  [[ -f "$file" ]] && grep -Fqx -- "$(os_marker_begin "$id" "$prefix")" "$file"
}

block_write() {
  local file="$1" id="$2" content="$3" prefix="${4:-#}" begin end tmp
  begin="$(os_marker_begin "$id" "$prefix")"
  end="$(os_marker_end "$id" "$prefix")"
  mkdir -p -- "$(dirname -- "$file")"
  touch -- "$file"
  tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file" >"$tmp"
  {
    cat "$tmp"
    printf '%s\n%s\n%s\n' "$begin" "$content" "$end"
  } >"$file"
  rm -f -- "$tmp"
}

block_remove() {
  local file="$1" id="$2" prefix="${3:-#}" begin end tmp
  [[ -f "$file" ]] || return 0
  begin="$(os_marker_begin "$id" "$prefix")"
  end="$(os_marker_end "$id" "$prefix")"
  tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f -- "$tmp"
}

state_set() {
  mkdir -p -- "$OS_STATE_DIR"
  printf '%s\n' "$2" >"$OS_STATE_DIR/$1"
}
state_get() { [[ -f "$OS_STATE_DIR/$1" ]] && cat -- "$OS_STATE_DIR/$1"; }
state_del() { rm -f -- "$OS_STATE_DIR/$1"; }

# `wc -L` counts display columns, so Hangul is 2 wide.
str_width() { printf '%s' "$1" | LC_ALL=C.UTF-8 wc -L; }

pad_to() {
  local text="$1" cols="$2" w
  w="$(str_width "$text")"
  printf '%s' "$text"
  ((w < cols)) && printf '%*s' $((cols - w)) ''
  return 0
}

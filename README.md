<p align="center">
  <img src="docs/assets/banner.svg" alt="omarchy-starter — Omarchy Linux first-day setup guide" width="880">
</p>

<p align="center">
  <strong>A single-file Korean field manual for the first day on Omarchy Linux —<br>
  every chapter pairs beginner commands with a copy-paste AI-agent prompt.</strong>
</p>

<p align="center">
  <a href="tests/"><img alt="tests: 19 passing" src="https://img.shields.io/badge/tests-19_passing-1f6f78"></a>
  <a href="index.html"><img alt="guide: single-file HTML" src="https://img.shields.io/badge/guide-single--file_HTML-b57920"></a>
  <img alt="license: to be declared" src="https://img.shields.io/badge/license-to_be_declared-9f4d2e">
</p>

<!-- README-I18N:START -->

**English** | [한국어](./README.ko.md)

<!-- README-I18N:END -->

**omarchy-starter** is a beginner's setup guide for [Omarchy](https://omarchy.org) Linux, published as one self-contained `index.html` — screenshots embedded, no build step, readable straight from [GitHub Pages](https://yelixir-dev.github.io/omarchy-starter/) or from a single downloaded file. Four chapters cover an optional AI coding agent (OMO), the required Korean input method (Fcitx5), palm rejection for 2019-or-earlier Intel Macs, and running Tailscale and NordVPN together without conflicts. Every chapter was executed and verified on a real Omarchy 4.0 machine before it was written down.

[What it does](#what-it-does) · [Install](#install) · [Usage](#usage) · [How it works](#how-it-works) · [Repository layout](#repository-layout) · [Current limitations](#current-limitations) · [License](#license)

## What it does

- **One file is the whole guide.** `index.html` embeds its screenshots as data URIs, so sharing that single file (or the Pages link) delivers the complete document.
- **Every chapter follows the same three blocks.** A plain-language explanation, direct Omarchy commands, and an "AI에게 맡기기" prompt a beginner can paste into an AI coding agent to have the task done for them.
- **Three scripts automate the hard parts.** `install-fcitx5-hangul.sh` (Korean input with timestamped profile backups), `install-intel-mac-palm-rejection.sh` (udev hwdb fix with `--dry-run` and `--uninstall`), and `manage-vpn-bypass-routes.sh` (user-managed non-Tailscale CIDR bypasses).
- **The VPN chapter documents a verified coexistence.** Tailscale mesh plus a NetworkManager OpenVPN profile — peer routes stay in Tailscale's table 52 while all other traffic uses Nord, with intentional fail-open and no kill switch.
- **The helper is regression-tested.** `tests/test-manage-vpn-bypass-routes.sh` runs 19 tests, including real network-namespace cases for concurrent applies, route migration, and failure rollback.

## Install

The guide itself needs no installation. To use the scripts, clone the repository:

```bash
git clone https://github.com/yelixir-dev/omarchy-starter.git
cd omarchy-starter
chmod +x install-fcitx5-hangul.sh install-intel-mac-palm-rejection.sh manage-vpn-bypass-routes.sh
```

The scripts target Omarchy/Arch Linux and ask for sudo where they touch the system.

## Usage

Open the guide and follow the chapters in order:

```bash
xdg-open index.html        # or open https://yelixir-dev.github.io/omarchy-starter/
```

Each "AI에게 맡기기" block is a complete prompt. Example trigger from the Korean-input chapter:

```text
내 컴퓨터는 Omarchy(Arch Linux)야.
https://github.com/yelixir-dev/omarchy-starter 저장소를 clone 받고, 그 안의
install-fcitx5-hangul.sh 스크립트로 Fcitx5 한글 입력기를 설치해줘.
```

Run the helper's test suite to verify the CIDR tool on your machine:

```bash
bash tests/test-manage-vpn-bypass-routes.sh    # 19 tests, last line prints 1..19
```

## How it works

1. The guide is read top to bottom: OMO (optional) → Korean input (required) → palm rejection (Intel Mac only) → VPN.
2. Each chapter starts with what and why in plain Korean, then numbered direct commands.
3. Scripts are idempotent: they back up existing state before changing it and refuse unsafe targets.
4. The VPN path installs Tailscale first (`--accept-routes=false`, no exit node), then NordVPN only as a NetworkManager OpenVPN profile with autoconnect off.
5. Verification commands close each chapter — public-IP checks, `tailscale ping`, table-52 route lookups, and the helper's 19-test suite.

## Repository layout

```text
index.html                              the single-file guide (images embedded)
install-fcitx5-hangul.sh                Fcitx5 Korean input installer
install-intel-mac-palm-rejection.sh     Intel Mac trackpad classification fix
install-fcitx5-bar-indicator.sh         bar K/E input-language indicator installer
install-vpn-bar-toggles.sh            installs only the VPN bar toggles you have
manage-vpn-bypass-routes.sh             non-Tailscale CIDR bypass manager
tests/test-manage-vpn-bypass-routes.sh  19-test regression suite for the helper
DESIGN.md                               design contract for the guide
```

## Current limitations

- The guide is written in Korean; there is no English translation of the guide itself yet.
- Commands assume Omarchy/Arch Linux (`omarchy pkg`, `pacman`); other distributions are out of scope.
- The VPN combination is intentional fail-open (no kill switch); suspend/resume and reboot persistence of the Nord profile were not tested and are not claimed.
- The palm-rejection script was verified on a `MacBookAir8,2`; other models should start from its `--dry-run`.

## License

to be declared

---

<p align="center"><em>omarchy-starter — a first-day field manual for Omarchy Linux.</em></p>

<p align="center">
  <img src="docs/assets/banner.svg" alt="omarchy-starter — Omarchy Linux first-day setup guide" width="880">
</p>

<p align="center">
  <strong>A first-day field manual for Omarchy Linux, in Korean and English —<br>
  one checklist installer, and every chapter pairs beginner commands with a copy-paste AI-agent prompt.</strong>
</p>

<p align="center">
  <a href="tests/"><img alt="tests: 35 passing" src="https://img.shields.io/badge/tests-35_passing-1f6f78"></a>
  <a href="omarchy-starter.html"><img alt="guide: single-file HTML" src="https://img.shields.io/badge/guide-single--file_HTML-b57920"></a>
  <img alt="license: to be declared" src="https://img.shields.io/badge/license-to_be_declared-9f4d2e">
</p>

<!-- README-I18N:START -->

**English** | [한국어](./README.ko.md)

<!-- README-I18N:END -->

**omarchy-starter** is a beginner's setup guide for [Omarchy](https://omarchy.org) Linux, published as one self-contained HTML file per language — `omarchy-starter.html` (Korean) and `omarchy-starter.en.html` (English) — with screenshots embedded, no build step, readable from [GitHub Pages](https://yelixir-dev.github.io/omarchy-starter/omarchy-starter.html) or from a single downloaded file. Six chapters cover the pre-install checklist, an optional AI coding agent (OMO), the required Korean input method (Fcitx5), palm rejection for 2019-or-earlier Intel Macs, running Tailscale and NordVPN together, and KakaoTalk plus Mac-style screenshots. A checklist installer, `install.sh`, does the same work from one terminal screen. Verified on Omarchy 4.0.2; the latest release at the time of writing is 4.0.4.

[What it does](#what-it-does) · [Install](#install) · [Usage](#usage) · [How it works](#how-it-works) · [Repository layout](#repository-layout) · [Current limitations](#current-limitations) · [Credits](#credits) · [License](#license)

## What it does

- **One file per language is the whole guide.** Both HTML files embed their screenshots as data URIs, so sharing one file (or the Pages link) delivers the complete document. Each links to the other.
- **Every chapter follows the same three blocks.** A plain-language explanation, direct Omarchy commands, and an "AI에게 맡기기" prompt a beginner can paste into an AI coding agent to have the task done for them.
- **One checklist installs everything.** `install.sh` probes what is already on the machine and shows a four-state list — `[v]` install, `[-]` keep, `[x]` remove, `[ ]` skip — with a description of the highlighted item on screen. Installed items start at `[-]`; missing required and recommended items start at `[v]`. Korean UI by default, `--lang en` for English.
- **Fifteen items, each its own step.** Required: system update, Korean input (`fcitx5-hangul`), nano as the default editor. Recommended: the OMO agent via bun, Korean/English key options (Right Alt as 한/영, the Super+Space menu in Latin), a bar K/E indicator, Mac-style screenshot keys, a password manager. Optional: Intel Mac palm rejection, KakaoTalk (Bottles or the Wine AUR package), Tailscale, VPN bar toggles, a browser, Syncthing, developer shell tools.
- **Eight scripts still work on their own.** `install-fcitx5-hangul.sh`, `install-fcitx5-bar-indicator.sh`, `install-screenshot-shortcuts.sh`, `install-vpn-bar-toggles.sh`, `install-kakaotalk-bottles.sh`, `patch-kakaotalk-korean-input.sh`, `install-intel-mac-palm-rejection.sh` (with `--dry-run` and `--uninstall`) and `manage-vpn-bypass-routes.sh`; the installer steps call them.
- **The VPN chapter documents a verified coexistence.** Tailscale mesh plus a NetworkManager OpenVPN profile — peer routes stay in Tailscale's table 52 while all other traffic uses Nord, with intentional fail-open and no kill switch.
- **The scripts are regression-tested.** `tests/` runs 35 checks: the CIDR helper (19, including real network-namespace cases), the KakaoTalk font patch (3) and the installer (13: state cycling, plan output, execution order, i18n key parity, the nano and Korean-key steps on a fake home).

## Install

Run the checklist from a fresh Omarchy terminal (it clones the repository into `~/.local/share/omarchy-starter`):

```bash
curl -fsSL https://raw.githubusercontent.com/yelixir-dev/omarchy-starter/main/install.sh | bash
```

For the English UI:

```bash
curl -fsSL https://raw.githubusercontent.com/yelixir-dev/omarchy-starter/main/install.sh | bash -s -- --lang en
```

Or clone it yourself and run the scripts by hand:

```bash
git clone https://github.com/yelixir-dev/omarchy-starter.git
cd omarchy-starter
./install.sh            # the checklist
./install-fcitx5-hangul.sh   # or any single script
```

The scripts target Omarchy/Arch Linux and ask for sudo where they touch the system.

## Usage

Open the guide and follow the chapters in order:

```bash
xdg-open omarchy-starter.html        # or open https://yelixir-dev.github.io/omarchy-starter/omarchy-starter.html
```

In the checklist, `↑↓` moves, `Space` changes the state, `Enter` runs, `q` quits. Non-interactive forms:

```bash
./install.sh --list                          # every item with its status and default action
./install.sh --dry-run --only korean,nano    # print the plan, run nothing
./install.sh --remove screenshots            # undo one item
./install.sh --all --choice password=bitwarden
```

Each "AI에게 맡기기" block is a complete prompt. Example trigger from the Korean-input chapter:

```text
내 컴퓨터는 Omarchy(Arch Linux)야.
https://github.com/yelixir-dev/omarchy-starter 저장소를 clone 받고, 그 안의
install-fcitx5-hangul.sh 스크립트로 Fcitx5 한글 입력기를 설치해줘.
```

Run the test suites to verify the tools on your machine:

```bash
bash tests/test-manage-vpn-bypass-routes.sh    # 19 tests, last line prints 1..19
bash tests/test-kakaotalk-korean-fonts.sh      # 3 tests
bash tests/test-installer.sh                   # 13 tests
```

## How it works

1. The guide is read top to bottom: pre-install checklist → OMO (optional) → Korean input (required) → palm rejection (Intel Mac only) → VPN → KakaoTalk and screenshots.
2. Each chapter starts with what and why in plain language, then numbered direct commands.
3. `install.sh` loads `steps/*.sh` in filename order; each step reports `installed`, `outdated` or `missing`, and implements `install` and `remove`. Removals run first in reverse order, then installs in order; one failure does not stop the rest.
4. Scripts are idempotent: they back up existing state before changing it, wrap every line they add to a user file in marker comments, and refuse unsafe targets.
5. The VPN path installs Tailscale first (`--accept-routes=false`, no exit node), then NordVPN only as a NetworkManager OpenVPN profile with autoconnect off.
6. Verification commands close each chapter — public-IP checks, `tailscale ping`, table-52 route lookups, and the test suites.

## Repository layout

```text
omarchy-starter.html                    the Korean single-file guide (images embedded)
omarchy-starter.en.html                 the English single-file guide
index.html                              Pages redirect to the Korean guide
install.sh                              checklist installer (clone/pull, probe, four-state list, run)
lib/common.sh, lib/ui.sh                shared helpers and the /dev/tty checklist
i18n/ko.sh, i18n/en.sh                  every UI string, item name and description
steps/NN-<id>.sh                        one file per item: status / install / remove
install-fcitx5-hangul.sh                Fcitx5 Korean input installer
install-fcitx5-bar-indicator.sh         bar K/E input-language indicator installer
install-screenshot-shortcuts.sh         Mac-style screenshot keys + bar capture button
install-vpn-bar-toggles.sh              installs only the VPN bar toggles you have
install-kakaotalk-bottles.sh            KakaoTalk on Bottles (Flatpak) installer
patch-kakaotalk-korean-input.sh         Korean font patch for the KakaoTalk bottle
install-intel-mac-palm-rejection.sh     Intel Mac trackpad classification fix
manage-vpn-bypass-routes.sh             non-Tailscale CIDR bypass manager
vpn-bypass-routes.conf.example          sample bypass list for the manager
tests/                                  35 regression checks across three suites
assets/                                 bar screenshots embedded in the guide
DESIGN.md                               design contract for the guide
```

## Current limitations

- Commands assume Omarchy/Arch Linux (`omarchy pkg`, `pacman`); other distributions are out of scope.
- The KakaoTalk Wine route installs the community AUR package `kakaotalk`; it was reviewed but not exercised on Omarchy, so the installer labels it experimental. The Bottles route is the tested one.
- The VPN combination is intentional fail-open (no kill switch); suspend/resume and reboot persistence of the Nord profile were not tested and are not claimed.
- The palm-rejection script was verified on a `MacBookAir8,2`; other models should start from its `--dry-run`.
- The checklist needs a terminal to ask on; in CI or scripts use `--all`, `--only` or `--remove`.

## Credits

- Key-mapping and installer-safety ideas (Right Alt as the Hangul key, the menu opening in Latin, fixed execution order, refusing to guess without a terminal) come from [minsoft1115/omarchy-setup](https://github.com/minsoft1115/omarchy-setup) and were reimplemented here.
- The guide's look follows [yelixir.dev](https://yelixir.dev); its fonts (Space Grotesk, DM Sans, Instrument Serif, JetBrains Mono) are used under the SIL Open Font License.

## License

to be declared

---

<p align="center"><em>omarchy-starter — a first-day field manual for Omarchy Linux.</em></p>

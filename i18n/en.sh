T[ui.title]='omarchy-starter · Choose what to install'
T[ui.keys]='↑↓ move   Space change   Enter run   a defaults   q quit'
T[ui.keys_one]='↑↓ move   Enter choose   q cancel'
T[legend.install]='install'
T[legend.keep]='keep'
T[legend.remove]='remove'
T[legend.none]='skip'
T[cat.required]='Required'
T[cat.recommended]='Recommended'
T[cat.optional]='Optional'
T[status.missing]='missing'
T[status.installed]='installed'
T[status.outdated]='update'
T[ui.changes]='Changes:'
T[ui.summary.title]='Plan'
T[ui.summary.counts]='install {i} · remove {r} · keep {k}'
T[ui.nothing]='Nothing to change.'
T[ui.dry_run]='--dry-run: nothing was run.'
T[ui.confirm.run]='Run this plan?'
T[ui.confirm.remove]='Some items will be removed. Run anyway?'
T[ui.cancel]='Cancelled. Nothing was changed.'
T[run.install]='Install'
T[run.remove]='Remove'
T[results.title]='Results'
T[results.ok]='[ok]'
T[results.fail]='[failed]'
T[results.log]='Log:'
T[err.notty]='No terminal to ask on. Name what you want with --all or --only.'
T[err.unknown_step]='Unknown item'
T[err.not_removable]='This item cannot be removed'
T[err.sudo]='Could not get administrator rights (sudo).'

T[update.name]='System update'
T[update.desc]='Brings Omarchy and system packages up to date (omarchy update).
Runs first: right after an offline install the package lists can be empty.'
T[update.changes]='package updates · a snapshot before updating'
T[update.status.installed]='current'
T[update.status.outdated]='needs update'

T[korean.name]='Korean input (fcitx5-hangul)'
T[korean.desc]='Omarchy ships Fcitx5 but not the Hangul engine.
Installs it with the config tool and adds English + Korean to the input group.
The default switch key is Ctrl+Space.'
T[korean.changes]='package fcitx5-hangul · ~/.config/fcitx5/profile (backed up) · undo: [x]'

T[nano.name]='nano as default editor'
T[nano.desc]='Installs nano, the easiest terminal editor, and makes it the default editor.
Git commit messages and the menu "edit config" actions open in nano.
Save with Ctrl+O, exit with Ctrl+X.'
T[nano.changes]='~/.local/state/omarchy/defaults/editor · undo restores the previous editor (Neovim)'
T[nano.done]='nano is now the default editor. It applies to new terminals.'

T[omo.name]='OMO coding agent'
T[omo.desc]='Installs OMO, an AI tool you talk to in the terminal.
Installs bun, adds ~/.bun/bin to PATH, then runs bun i -g omo-ai.
Afterwards run omo and sign in with /login.'
T[omo.changes]='bun (mise) · one PATH line in ~/.bashrc · ~/.bun/bin/omo'
T[omo.need_bun]='Could not install bun. Install it from https://bun.sh first.'
T[omo.need_node]='node is missing. Install it with: omarchy install dev-env node'
T[omo.done]='Installed. Open a new terminal, run omo and type /login.'
T[omo.not_bun]='This omo was not installed with bun. If npm installed it, run: npm rm -g omo-ai'

T[korean-keys.name]='Korean/English key'
T[korean-keys.desc]='Uses Right Alt (Right Option on a Mac) as the Korean/English key.
The Super+Space menu always opens in English input, so searches never turn into Hangul.
Optionally frees Ctrl+Space for programs such as tmux.'
T[korean-keys.changes]='one marked line in ~/.config/hypr/hyprland.lua · ~/.config/omarchy-starter/hypr/korean-keys.lua'
T[korean-keys.choice.title]='What should Ctrl+Space do?'
T[korean-keys.choice.keep-ctrl-space]='Both Right Alt and Ctrl+Space switch (recommended)'
T[korean-keys.choice.ralt-only]='Only Right Alt switches (leave Ctrl+Space to tmux etc.)'
T[korean-keys.no_hypr]='Hyprland config file not found'
T[korean-keys.done]='Korean/English key set. Try switching with Right Alt.'

T[hangul-indicator.name]='Bar Korean/English indicator'
T[hangul-indicator.desc]='Shows the current input language on the right of the bar: K (Korean) / E (English).'
T[hangul-indicator.changes]='~/.config/omarchy/plugins/user.fcitx-state · bar restart'

T[screenshots.name]='Mac-style screenshot keys'
T[screenshots.desc]='For laptops without a Print key: Super+Shift+9 captures an area, Super+Shift+0 the whole screen.
Also adds a capture button to the bar. Workspace 9/10 move shortcuts on the same keys are released.'
T[screenshots.changes]='~/.config/hypr/bindings.lua (backed up) · bar plugin user.capture-button'

T[password.name]='Password manager'
T[password.desc]='Installs 1Password or Bitwarden, whichever you already use.
Uses the official Omarchy installer.'
T[password.changes]='the chosen app package'
T[password.choice.title]='Which password manager should be installed?'
T[password.choice.1password]='1Password (with the Chromium extension)'
T[password.choice.bitwarden]='Bitwarden (app + CLI)'

T[palm.name]='Intel Mac palm rejection'
T[palm.desc]='Fixes palms touching the trackpad while typing on 2019-or-earlier Intel Macs.
Shows a dry run of the change first, then applies it. Only listed on Intel Macs.'
T[palm.changes]='/etc/udev/hwdb.d/70-apple-internal-touchpad.hwdb'

T[kakaotalk.name]='KakaoTalk'
T[kakaotalk.desc]='Runs the Windows KakaoTalk app on Linux. You choose how it is installed.
Bottles: the tested route (with font and Korean input patches). Wine (AUR): lighter but experimental.
Installing both gives two KakaoTalk apps with separate logins and data.'
T[kakaotalk.changes]='Bottles: Flatpak + a bottle · Wine: AUR package kakaotalk'
T[kakaotalk.choice.title]='How should KakaoTalk be installed?'
T[kakaotalk.choice.bottles]='Bottles (recommended · tested)'
T[kakaotalk.choice.wine]='Wine AUR package (experimental · lighter)'
T[kakaotalk.choice.both]='Both (two KakaoTalk apps · separate logins)'
T[kakaotalk.wine_hint]='Installed. Run kakaotalk once in a terminal to finish installing the Windows client.'
T[kakaotalk.wine_data]='Chat data was kept. Delete this folder to remove it completely'

T[tailscale.name]='Tailscale'
T[tailscale.desc]='Joins your devices into one private network, set up the way this guide does (--accept-routes=false).
The Omarchy menu installer accepts routes from other devices, so it is not used here.'
T[tailscale.changes]='package tailscale · tailscaled service · browser sign-in'

T[vpn-toggles.name]='VPN bar toggles'
T[vpn-toggles.desc]='Adds on/off buttons to the bar for the VPNs you have (Tailscale, a NordVPN OpenVPN profile).'
T[vpn-toggles.changes]='bar plugins user.tailscale-toggle / user.nordvpn-toggle'

T[browser.name]='Extra browser'
T[browser.desc]='Installs a familiar browser next to Chromium (official Omarchy installer).
Change the default browser in the menu under Setup > Defaults > Browser.'
T[browser.changes]='the chosen browser package'
T[browser.choice.title]='Which browser should be installed?'
T[browser.choice.firefox]='Firefox'
T[browser.choice.brave]='Brave'
T[browser.choice.zen]='Zen'

T[sync.name]='Syncthing file sync'
T[sync.desc]='Syncs folders directly with your other devices, no cloud involved.
Afterwards open http://127.0.0.1:8384 in a browser to set it up. It is not a backup.'
T[sync.changes]='package syncthing · user service syncthing.service'
T[sync.done]='Syncthing is running. Set it up at http://127.0.0.1:8384'

T[dev-shell.name]='Developer shell tools'
T[dev-shell.desc]='Terminal conveniences: Alt+R searches command history with fzf, git diffs through delta,
md renders markdown (glow), and lazygit uses delta too.'
T[dev-shell.changes]='one marked line in ~/.bashrc · 3 global git settings (restorable) · lazygit config'
T[dev-shell.lazygit_skip]='The lazygit config already has content, so it was left alone'
T[dev-shell.done]='Alt+R history search works in new terminals.'

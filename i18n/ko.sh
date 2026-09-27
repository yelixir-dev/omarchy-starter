T[ui.title]='omarchy-starter · 설치할 항목을 고르세요'
T[ui.keys]='↑↓ 이동   Space 상태 바꾸기   Enter 실행   a 기본값으로   q 종료'
T[ui.keys_one]='↑↓ 이동   Enter 선택   q 취소'
T[legend.install]='설치'
T[legend.keep]='유지'
T[legend.remove]='제거'
T[legend.none]='선택 안 함'
T[cat.required]='필수'
T[cat.recommended]='권장'
T[cat.optional]='선택'
T[status.missing]='미설치'
T[status.installed]='설치됨'
T[status.outdated]='업데이트'
T[ui.changes]='바뀌는 것:'
T[ui.summary.title]='실행 계획'
T[ui.summary.counts]='설치 {i} · 제거 {r} · 유지 {k}'
T[ui.nothing]='바꿀 항목이 없습니다.'
T[ui.dry_run]='--dry-run: 아무것도 실행하지 않았습니다.'
T[ui.confirm.run]='위 계획대로 실행할까요?'
T[ui.confirm.remove]='제거할 항목이 있습니다. 정말 실행할까요?'
T[ui.cancel]='취소했습니다. 아무것도 바꾸지 않았습니다.'
T[run.install]='설치'
T[run.remove]='제거'
T[results.title]='결과'
T[results.ok]='[성공]'
T[results.fail]='[실패]'
T[results.log]='기록:'
T[err.notty]='물어볼 터미널이 없습니다. --all 또는 --only 로 원하는 항목을 지정하세요.'
T[err.unknown_step]='알 수 없는 항목'
T[err.not_removable]='제거할 수 없는 항목'
T[err.sudo]='관리자 권한(sudo)을 얻지 못했습니다.'

T[update.name]='시스템 업데이트'
T[update.desc]='Omarchy와 시스템 패키지를 최신으로 맞춥니다(omarchy update).
오프라인 설치 직후에는 패키지 목록이 비어 있을 수 있어 가장 먼저 합니다.'
T[update.changes]='패키지 업데이트 · 업데이트 전 스냅샷'
T[update.status.installed]='최신'
T[update.status.outdated]='업데이트 필요'

T[korean.name]='한글 입력 (fcitx5-hangul)'
T[korean.desc]='Omarchy에 Fcitx5는 이미 있지만 한글 엔진이 없습니다.
한글 엔진과 설정 도구를 설치하고 영문 키보드와 한글을 입력기 그룹에 등록합니다.
기본 전환키는 Ctrl+Space 입니다.'
T[korean.changes]='패키지 fcitx5-hangul · ~/.config/fcitx5/profile(백업 후) · 되돌리기: [x]'

T[nano.name]='nano 기본 에디터'
T[nano.desc]='가장 쉬운 터미널 에디터 nano를 설치하고 기본 에디터로 정합니다.
git 커밋 메시지나 메뉴의 "설정 편집"이 nano로 열립니다.
저장은 Ctrl+O, 종료는 Ctrl+X 입니다.'
T[nano.changes]='~/.local/state/omarchy/defaults/editor · 되돌리면 이전 에디터(Neovim)로 복원'
T[nano.done]='기본 에디터를 nano로 바꿨습니다. 새 터미널부터 적용됩니다.'

T[omo.name]='OMO 코딩 에이전트'
T[omo.desc]='터미널에서 대화하듯 일을 맡기는 AI 도구 OMO를 설치합니다.
bun을 설치하고 PATH에 ~/.bun/bin을 더한 뒤 bun i -g omo-ai 를 실행합니다.
설치 후 omo 를 실행하고 /login 으로 로그인하세요.'
T[omo.changes]='bun(mise) · ~/.bashrc에 PATH 한 줄 · ~/.bun/bin/omo'
T[omo.need_bun]='bun을 설치할 수 없습니다. https://bun.sh 에서 먼저 설치하세요.'
T[omo.need_node]='node가 없습니다. omarchy install dev-env node 로 먼저 설치하세요.'
T[omo.done]='설치했습니다. 새 터미널에서 omo 를 실행하고 /login 을 입력하세요.'
T[omo.not_bun]='bun으로 설치한 omo가 아닙니다. npm으로 설치했다면 npm rm -g omo-ai 로 지우세요.'

T[korean-keys.name]='한/영 키 설정'
T[korean-keys.desc]='오른쪽 Alt(Mac은 오른쪽 Option)를 한/영 키로 씁니다.
Super+Space 메뉴는 항상 영문 입력으로 열려서 검색어가 한글로 꼬이지 않습니다.
원하면 Ctrl+Space를 한/영 전환에서 빼서 tmux 같은 프로그램에 양보합니다.'
T[korean-keys.changes]='~/.config/hypr/hyprland.lua에 한 줄(표시 포함) · ~/.config/omarchy-starter/hypr/korean-keys.lua'
T[korean-keys.choice.title]='Ctrl+Space는 어떻게 할까요?'
T[korean-keys.choice.keep-ctrl-space]='오른쪽 Alt와 Ctrl+Space 둘 다 한/영 전환 (추천)'
T[korean-keys.choice.ralt-only]='오른쪽 Alt만 한/영 전환 (Ctrl+Space는 tmux 등에 양보)'
T[korean-keys.no_hypr]='Hyprland 설정 파일이 없습니다'
T[korean-keys.done]='한/영 키를 설정했습니다. 오른쪽 Alt로 전환해 보세요.'

T[hangul-indicator.name]='상태바 한/영 표시'
T[hangul-indicator.desc]='상태바 오른쪽에 지금 입력 언어를 K(한국어) / E(영어)로 보여줍니다.'
T[hangul-indicator.changes]='~/.config/omarchy/plugins/user.fcitx-state · 상태바 재시작'

T[screenshots.name]='Mac식 스크린샷 단축키'
T[screenshots.desc]='Print 키가 없는 노트북용입니다. Super+Shift+9 영역 캡처, Super+Shift+0 전체 캡처.
상태바에 캡처 버튼도 추가합니다. 같은 키를 쓰던 작업공간 9/10 이동 단축키는 해제됩니다.'
T[screenshots.changes]='~/.config/hypr/bindings.lua(백업 후) · 상태바 플러그인 user.capture-button'

T[password.name]='비밀번호 관리자'
T[password.desc]='1Password 또는 Bitwarden 중 이미 쓰는 것을 설치합니다.
Omarchy 공식 설치기를 사용합니다.'
T[password.changes]='선택한 앱 패키지'
T[password.choice.title]='어떤 비밀번호 관리자를 설치할까요?'
T[password.choice.1password]='1Password (Chromium 확장 포함)'
T[password.choice.bitwarden]='Bitwarden (앱 + CLI)'

T[palm.name]='Intel Mac 팜 리젝션'
T[palm.desc]='2019년형 이하 Intel Mac에서 타이핑 중 손바닥이 트랙패드를 건드리는 문제를 고칩니다.
먼저 드라이런으로 바뀔 내용을 보여준 뒤 적용합니다. Intel Mac에서만 보입니다.'
T[palm.changes]='/etc/udev/hwdb.d/70-apple-internal-touchpad.hwdb'

T[kakaotalk.name]='카카오톡'
T[kakaotalk.desc]='Windows용 카카오톡을 리눅스에서 실행합니다. 설치 방식을 고를 수 있습니다.
Bottles: 검증된 방식(폰트·한글 입력 패치 포함). Wine(AUR): 더 가볍지만 실험적입니다.
둘 다 설치하면 카카오톡이 두 개 생기고 로그인과 데이터도 따로입니다.'
T[kakaotalk.changes]='Bottles: Flatpak + 병(bottle) · Wine: AUR 패키지 kakaotalk'
T[kakaotalk.choice.title]='카카오톡을 어떤 방식으로 설치할까요?'
T[kakaotalk.choice.bottles]='Bottles (권장 · 검증됨)'
T[kakaotalk.choice.wine]='Wine AUR 패키지 (실험적 · 가벼움)'
T[kakaotalk.choice.both]='둘 다 (카카오톡 2개 · 로그인 따로)'
T[kakaotalk.wine_hint]='설치했습니다. 터미널에서 kakaotalk 을 한 번 실행하면 Windows용 카카오톡 설치가 이어집니다.'
T[kakaotalk.wine_data]='대화 데이터는 남겨 두었습니다. 완전히 지우려면 이 폴더를 삭제하세요'

T[tailscale.name]='Tailscale'
T[tailscale.desc]='내 기기들을 하나의 사설 네트워크로 묶습니다. 이 안내서의 방식(--accept-routes=false)으로 설치합니다.
Omarchy 메뉴의 Tailscale 설치기는 다른 기기의 경로를 받아들이므로 여기서는 쓰지 않습니다.'
T[tailscale.changes]='패키지 tailscale · tailscaled 서비스 · 브라우저 로그인'

T[vpn-toggles.name]='VPN 상태바 토글'
T[vpn-toggles.desc]='설치된 VPN(Tailscale, NordVPN OpenVPN 프로필)만 골라 상태바에 켜고 끄는 버튼을 넣습니다.'
T[vpn-toggles.changes]='상태바 플러그인 user.tailscale-toggle / user.nordvpn-toggle'

T[browser.name]='브라우저 추가'
T[browser.desc]='Chromium 말고 익숙한 브라우저를 하나 더 설치합니다(Omarchy 공식 설치기).
기본 브라우저는 메뉴 Setup > Defaults > Browser 에서 바꿉니다.'
T[browser.changes]='선택한 브라우저 패키지'
T[browser.choice.title]='어떤 브라우저를 설치할까요?'
T[browser.choice.firefox]='Firefox'
T[browser.choice.brave]='Brave'
T[browser.choice.zen]='Zen'

T[sync.name]='Syncthing 파일 동기화'
T[sync.desc]='내 다른 기기와 폴더를 직접 동기화합니다(클라우드 없이).
설치 후 브라우저에서 http://127.0.0.1:8384 를 열어 설정합니다. 백업을 대신하지는 않습니다.'
T[sync.changes]='패키지 syncthing · 사용자 서비스 syncthing.service'
T[sync.done]='Syncthing을 켰습니다. http://127.0.0.1:8384 에서 설정하세요.'

T[dev-shell.name]='개발자 셸 도구'
T[dev-shell.desc]='터미널 편의 기능: Alt+R로 명령 기록을 fzf로 검색, git diff를 delta로 보기,
md 명령으로 마크다운 보기(glow), lazygit에서도 delta 사용.'
T[dev-shell.changes]='~/.bashrc에 한 줄(표시 포함) · git 전역 설정 3개(되돌리기 가능) · lazygit 설정'
T[dev-shell.lazygit_skip]='lazygit 설정 파일에 이미 내용이 있어 건드리지 않았습니다'
T[dev-shell.done]='새 터미널부터 Alt+R 기록 검색이 켜집니다.'

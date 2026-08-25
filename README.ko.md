<p align="center">
  <img src="docs/assets/banner.svg" alt="omarchy-starter — Omarchy Linux 첫날 설정 안내서" width="880">
</p>

<p align="center">
  <strong>Omarchy Linux 첫날을 위한 단일 파일 한국어 안내서 —<br>
  모든 장이 초보자 명령어와 AI 에이전트용 복사 프롬프트를 함께 제공합니다.</strong>
</p>

<p align="center">
  <a href="tests/"><img alt="테스트: 19 통과" src="https://img.shields.io/badge/tests-19_passing-1f6f78"></a>
  <a href="index.html"><img alt="가이드: 단일 파일 HTML" src="https://img.shields.io/badge/guide-single--file_HTML-b57920"></a>
  <img alt="라이선스: to be declared" src="https://img.shields.io/badge/license-to_be_declared-9f4d2e">
</p>

<!-- README-I18N:START -->

[English](./README.md) | **한국어**

<!-- README-I18N:END -->

**omarchy-starter**는 [Omarchy](https://omarchy.org) Linux 초보자를 위한 설치 안내서로, 스크린샷까지 내장한 단일 `index.html` 하나로 배포됩니다. 빌드 과정 없이 [GitHub Pages](https://yelixir-dev.github.io/omarchy-starter/)에서 바로 읽거나 파일 하나만 내려받아 열어볼 수 있습니다. 네 개의 장에서 AI 코딩 에이전트(OMO, 선택), 한국어 입력기(Fcitx5, 필수), 2019년 이하 Intel Mac 팜 리젝션, Tailscale과 NordVPN의 충돌 없는 동시 사용을 다룹니다. 모든 장은 실제 Omarchy 4.0 장비에서 직접 실행하고 검증한 뒤 작성됐습니다.

[무엇을 하나요](#무엇을-하나요) · [설치](#설치) · [사용법](#사용법) · [동작 방식](#동작-방식) · [저장소 구성](#저장소-구성) · [현재 한계](#현재-한계) · [라이선스](#라이선스)

## 무엇을 하나요

- **파일 하나가 안내서 전부입니다.** `index.html`이 스크린샷을 data URI로 내장해서, 파일 하나(또는 Pages 링크)만 전달해도 문서 전체가 열립니다.
- **모든 장이 같은 3단 구조입니다.** 초보자용 설명, 직접 따라 하는 Omarchy 명령어, 그리고 AI 코딩 에이전트에 붙여넣어 작업을 맡길 수 있는 "AI에게 맡기기" 프롬프트입니다.
- **스크립트 3개가 어려운 부분을 자동화합니다.** `install-fcitx5-hangul.sh`(날짜 백업을 포함한 한글 입력 설치), `install-intel-mac-palm-rejection.sh`(`--dry-run`과 `--uninstall`을 갖춘 udev hwdb 수정), `manage-vpn-bypass-routes.sh`(사용자 관리 비-Tailscale CIDR 우회)입니다.
- **VPN 장은 실제 검증된 공존을 다룹니다.** Tailscale mesh와 NetworkManager OpenVPN 프로필 조합으로, 피어 경로는 Tailscale table 52에 두고 나머지 트래픽만 Nord를 타게 하며, kill switch 없이 의도적으로 fail-open 합니다.
- **도구는 회귀 테스트를 거쳤습니다.** `tests/test-manage-vpn-bypass-routes.sh`가 동시 apply, 경로 이전, 실패 롤백을 포함한 실제 네트워크 네임스페이스 테스트 19개를 실행합니다.

## 설치

안내서 자체는 설치가 필요 없습니다. 스크립트를 사용하려면 저장소를 받으세요:

```bash
git clone https://github.com/yelixir-dev/omarchy-starter.git
cd omarchy-starter
chmod +x install-fcitx5-hangul.sh install-intel-mac-palm-rejection.sh manage-vpn-bypass-routes.sh
```

스크립트는 Omarchy/Arch Linux를 대상으로 하며 시스템을 바꾸는 단계에서 sudo를 묻습니다.

## 사용법

안내서를 열고 장을 순서대로 따라 하세요:

```bash
xdg-open index.html        # 또는 https://yelixir-dev.github.io/omarchy-starter/ 접속
```

각 "AI에게 맡기기" 블록은 완성된 프롬프트입니다. 한글 입력기 장의 예시:

```text
내 컴퓨터는 Omarchy(Arch Linux)야.
https://github.com/yelixir-dev/omarchy-starter 저장소를 clone 받고, 그 안의
install-fcitx5-hangul.sh 스크립트로 Fcitx5 한글 입력기를 설치해줘.
```

내 장비에서 CIDR 도구를 검증하려면 테스트를 실행하세요:

```bash
bash tests/test-manage-vpn-bypass-routes.sh    # 19개 테스트, 마지막 줄에 1..19 출력
```

## 동작 방식

1. 안내서는 위에서 아래로 읽습니다: OMO(선택) → 한글 입력기(필수) → 팜 리젝션(Intel Mac만) → VPN.
2. 각 장은 무엇인지·왜 하는지를 쉬운 한국어로 시작하고, 번호가 매겨진 직접 명령어로 이어집니다.
3. 스크립트는 멱등입니다: 변경 전에 기존 상태를 백업하고 안전하지 않은 대상은 거부합니다.
4. VPN 경로는 Tailscale을 먼저 설치하고(`--accept-routes=false`, exit node 없음), NordVPN은 NetworkManager OpenVPN 프로필로만 올리며 자동 연결은 끕니다.
5. 각 장의 마지막은 검증 명령으로 닫습니다 — 공인 IP 확인, `tailscale ping`, table 52 경로 조회, 도구의 19개 테스트입니다.

## 저장소 구성

```text
index.html                              단일 파일 안내서(이미지 내장)
install-fcitx5-hangul.sh                Fcitx5 한글 입력 설치 스크립트
install-intel-mac-palm-rejection.sh     Intel Mac 트랙패드 분류 수정 스크립트
install-fcitx5-bar-indicator.sh         상태바 입력 언어(K/E) 표시 설치 스크립트
manage-vpn-bypass-routes.sh             비-Tailscale CIDR 우회 관리 도구
tests/test-manage-vpn-bypass-routes.sh  도구 회귀 테스트 19개
DESIGN.md                               안내서 디자인 계약
```

## 현재 한계

- 안내서는 한국어로만 작성됐으며, 안내서 본문의 영어 번역은 아직 없습니다.
- 명령어는 Omarchy/Arch Linux(`omarchy pkg`, `pacman`)를 기준으로 하며 다른 배포판은 범위 밖입니다.
- VPN 조합은 의도적인 fail-open(kill switch 없음)이며, 절전/복귀와 재부팅 후 Nord 프로필 지속성은 검증하지 않았고 주장하지도 않습니다.
- 팜 리젝션 스크립트는 `MacBookAir8,2`에서 검증됐으니, 다른 모델은 `--dry-run`부터 시작하세요.

## 라이선스

to be declared

---

<p align="center"><em>omarchy-starter — Omarchy Linux 첫날을 위한 현장 안내서.</em></p>

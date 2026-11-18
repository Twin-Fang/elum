# 루미 위젯 묶음 설계 (#1465)

2026-11-18 대표와 합의. 대표가 설계를 위임했다 ("너가 잘 설계해 줘, 예쁘게, 친근하게").

## 왜
리텐션이 낮다. 앱을 매일 다시 열게 만드는 장치가 부족하다. iOS 홈 위젯은 보호자용 1종(#1410, 출시 전), Android 홈 위젯은 없고, Android 잠금화면 카드는 Play 신고(#1420) 전이라 꺼져 있다.

## 목표 · 하지 않는 것
- 듀오링고처럼 **루미가 주인공**: 상태·시간대마다 표정과 한마디가 바뀐다. 친근한 말투, 앱을 다시 열고 싶게.
- iOS·Android **둘 다 여러 종류**의 위젯. 누르면 그 화면으로 바로 간다.
- 하지 않는 것: 이룸이 화면·위젯·잠금화면의 광고·판매 문구. 죄책감·겁주기(슬픈 루미, "끊겨요"). 알림 권한 흐름(다른 세션).
- 실패 경로: 요약이 없거나 어제 것이면 "루미랑 오늘 할 일 볼까요?" + 앱 열기. 카드 그림 파일이 없으면 루미가 카드를 든 그림. 위젯은 네트워크를 쓰지 않는다.

## 방식 (검토한 안)
- **A (고름)**: 플랫폼 원래 방식 — iOS WidgetKit(SwiftUI), Android AppWidget(RemoteViews). 앱은 오늘 요약 JSON 하나만 저장하고 두 위젯이 읽는다. 지금 iOS 위젯과 Android 잠금화면 카드가 이미 이 구조.
- B: Flutter 화면을 이미지로 찍어 붙이기 — 글이 흐리고 누르기 범위가 좁아 고도화에 안 맞음.
- Android 는 Glance 대신 RemoteViews (내 판단): Compose 컴파일러 플러그인 추가 없이 지금 빌드 그대로, 크기별 레이아웃(API 31+ 반응형)도 된다.

## 단계
- **1단계 (이 이슈)**: 루미 표정 16종, 캐릭터 문서, 위젯 3종 × 2플랫폼, iOS 잠금화면 위젯, 누르면 바로 이동.
- **2단계**: 위젯 안에서 카드 체크(iOS 17+, Android), 일과 목록·빠른 만들기 위젯, 잠금화면 카드 이룸이 전용 정리.

## 데이터: 오늘 요약 JSON (단일 원본 `client/lib/core/lock_screen/lock_screen_snapshot.dart`)
기존 필드: `mode`(guardian|elumi), `dateKey`(yyyy-MM-dd), `doneCount`, `totalCount`, `nextRoutineTitle`, `elumiCard{routineId, cardId, routineTitle, cardText, contentLanguage, imageFilePath, pictogramId, exampleImageId}`, `activeWindows`.
추가 필드 (없으면 기본값): `elumiName`(String?, 이룸이 이름), `streakDays`(int, 0), `starCount`(int, 0).
- iOS: `elum/home_widget` 채널이 App Group `group.kr.twinfang.elum` 의 `elum.lockScreenSnapshot` 에 저장. 카드 그림 파일은 App Group 컨테이너 `widget/card.png` 로 복사해 `imageFilePath` 를 그 경로로 바꿔 저장 (위젯 확장은 앱 폴더를 못 읽음).
- Android: `elum/lock_screen` 채널이 `LockScreenPreferences.snapshotJson` 에 저장 > 저장할 때 위젯 전부 갱신.
- 보호자·이룸이 기기 모두 요약을 보낸다 (지금은 iOS 가 보호자만 보냄).

## 루미 상태 (두 플랫폼 같은 규칙, 위에서부터 먼저 맞는 것)
| 상태 | 조건 | 루미 그림 | 보호자 기기 문구 | 이룸이 기기 문구 |
|---|---|---|---|---|
| stale | 요약 없음 · 날짜 다름 | lumi_hello | 루미랑 오늘 일과 볼까요? | 루미랑 오늘 할 일 볼까요? |
| empty | totalCount 0 | 보호자 lumi_new_routine · 이룸이 lumi_resting | 오늘 일과를 만들어 볼까요? | 오늘은 쉬는 날이에요 |
| done | doneCount ≥ totalCount | lumi_celebrate_star | {이름}가 오늘 다 했어요! | 오늘 다 했어요! 최고예요 |
| night | 21시 이후, 덜 함 | lumi_sleepy | 내일 또 같이 해요 | 내일 또 같이 해요 |
| evening | 18시 이후, 0개 | lumi_waiting | {이름}를 루미가 기다리고 있어요 | 루미가 기다리고 있어요 |
| morning | 12시 전, 0개 | lumi_hello | 좋은 아침! 오늘 일과 {n}개 | 좋은 아침! 오늘 할 일 {n}개 |
| ready | 0개 (그 밖) | lumi_holding_card | 오늘 일과 {n}개가 기다려요 | 시작해 볼까요? 할 일 {n}개 |
| progress | 1개 이상, 덜 함 | lumi_cheer | {이름}가 {done}/{total} 했어요 | 잘하고 있어요! {done}/{total} |
- {이름} 이 없으면 "이룸이". 조사(가/이, 를/을)는 쓰지 않게 문구를 "{이름} · 2/3 했어요" 처럼 바꾸지 말고, 이름 없는 버전 문구를 기본으로: 보호자 progress "오늘 {done}/{total} 했어요", done "오늘 일과를 다 했어요!", evening "루미가 기다리고 있어요" (1단계는 이름 없이 간다 — 조사·5개 언어 문제를 피함. 위젯 머리에 이름만 따로 보임).

## 위젯 3종
| 위젯 | 크기 | 내용 | 누르면 |
|---|---|---|---|
| 오늘 루미 (Today) | 소·중 | 루미 상태 그림 + 한마디 + 진행 막대 + 다음 할 일 | home |
| 지금 할 카드 (Now card) | 소·중·대 | 카드 그림(없으면 lumi_holding_card) + 카드 글 + 일과 제목 + 진행 n/m. 카드 없으면 오늘 루미와 같은 상태 화면 | `routine:{id}` · 없으면 home |
| 별과 연속 (Streak) | 소 | lumi_streak_flame + "{n}일 연속" + 별 {k} (연속 2일 미만이면 lumi_idle + 별만) | home |
- iOS 잠금화면 (iOS 16+): 원형(진행 링 + done/total), 직사각형(루미 한마디 + done/total), 한 줄(다음 할 일).
- 모양: 흰 판(#FFFFFF), 모서리 큼, 진한 글 #242634, 회색 글 #898B98, 진행 막대 민트 #55CFBA / 트랙 #EEE9E6, 강조 노랑 #FFD629. 다크모드는 판 #23252F 글 흰색.
- 위젯 이름(목록): 오늘 루미 · 지금 할 카드 · 별과 연속.

## 이동 경로
경로 문자열은 Android 잠금화면 카드와 같다 (`home`, `routine:{id}`). Android 는 MainActivity extra `elum_lock_screen_route`, iOS 는 `elum://widget?route=...` URL > 앱이 같은 경로 처리기(`lock_screen_route_opener.dart`)로 연다.

## 측정
위젯을 누르면 앱이 `[widget] open route : <route> from <widget>` 로그를 남긴다. 설치 수·누른 수 서버 집계는 2단계.

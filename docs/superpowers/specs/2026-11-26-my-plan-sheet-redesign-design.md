# 내 요금제 시트를 금빛 회원 카드와 움직임으로 개편 (#1516)

2026-11-26 · 이슈 https://github.com/Twin-Fang/elum/issues/1516

## 문제

- 설정 > `내 요금제` 시트의 머리에 제목과 PRO 칩만 있어 허전하다 (2026-11-26 사용자 의견)
- 알려 주는 사실이 `끝나는 날` 한 줄뿐이고, Pro로 무엇을 쓰고 있는지 보이지 않는다
- `구매 복원`, `닫기` 가 같은 회색 판 두 줄로 쌓여 무게가 같다
- 움직임은 묶음 떠오름 하나뿐이다

## 목표와 하지 않는 것

- 목표: 설정에서 들어와도 내 정보와 같은 "Pro 회원 카드" 인상을 주고, 남은 날과 쓰는 혜택이 한눈에 보인다
- 하지 않는 것: 결제, 복원, 구독 관리 동작과 서버 변경. Free 회원의 흐름(요금제 화면). 기간 진행 막대(서버가 시작일을 주지 않는다). 비교 유도 문구

## 검토한 안

| 안 | 내용 | 결정 |
|---|---|---|
| A. 금빛 회원 카드 | 시트 내용 맨 위에 내 정보와 같은 금빛 카드. 루미, 요금제 칩, 남은 날 큰 숫자, 혜택 알약 3개. 버튼 한 줄 | 채택. 표 줄과 버튼 갈래가 그대로라 동작이 안 바뀐다 |
| B. 루미 그림 머리 | 지금 뼈대에 루미 그림 120만 얹음 | 혜택이 여전히 안 보인다. 버림 |
| C. 전체 화면 | 시트 대신 새 화면에 혜택 전체 목록, 결제 정보 | 알릴 사실이 날짜 하나뿐인데 무겁고 요금제 화면과 겹친다. 버림 |

사용자가 부재 중이라 추천안 진행을 위임했다. 시안은 이슈 본문에 있다.

## 설계

- 뼈대는 `ElumGuidePanel(sheet)` 그대로. 제목 `내 요금제` > 내용(회원 카드 > 표 줄 > 설명) > 주 버튼 > 보조 버튼 묶음
- `core/widgets/pro_member_card.dart`: `ProMemberCardSurface`(금빛 판, 테두리, 그림자, 모서리 빛, 빛 띠 한 번), `ProMemberBenefitPill`. 내 정보 `MyPlanCard` 가 같이 쓴다
- `subscription/presentation/my_plan_sheet_hero.dart`: `MyPlanSheetHero` (루미 > 칩 > 큰 글 > 알약)
- `subscription/application/plan_status_providers.dart`: `planDaysLeft`, `planSheetHeadline`
- `subscription/application/pro_member_benefit_labels.dart`: `watchProMemberBenefitLabels` (알약 문구 한 곳)
- `core/l10n/date_labels.dart`: `lastUsableDayOf` (마지막으로 쓸 수 있는 날 규칙을 날짜 표시와 남은 날 계산이 같이 씀)

큰 글

| 상태 | 큰 글 |
|---|---|
| 선물, 기간제, 해지 예약 (끝나는 날 있음) | `N일 남았어요`, 마지막 날은 `오늘까지 쓸 수 있어요` |
| 체험 | `Pro 체험 중, N일 남았어요` (기존 문구) |
| 자동 갱신, 기간 제한 없음, 결제 확인 필요, 날짜 모름 | `Pro로 쓰고 있어요` (선물은 `Pro 선물을 받았어요`) |

움직임 (동작 줄이기가 켜져 있으면 모두 끝 모습)

| 순서 | 무엇 | 부품, 토큰 |
|---|---|---|
| 1 | 내용 묶음 떠오름 | 뼈대 `AppReveal`, `sectionStagger` |
| 2 | 루미 톡 튀어나옴 | `AppPopIn`, `emphasis` |
| 3 | 빛 띠가 카드를 한 번 쓸고 지나감 | `ProMemberCardSurface`, `slow` 뒤 `shineSweep`(700, 새 토큰) |
| 4 | 남은 날 숫자가 0에서 세어 올라감 | `AppCountUp`, `countUp` |
| 5 | 혜택 알약이 차례로 | `AppReveal`, `staggerStep` |
| 늘 | 루미 둘레 네 갈래 빛이 천천히 반짝임 | `TwinkleStarField` |

## 실패 경로

| 상황 | 화면 |
|---|---|
| 구독 정보 없음 (회원 정보를 못 받음) | 날짜 줄 없이 `Pro로 쓰고 있어요` 카드. 0일이나 빈 칸을 보이지 않는다 |
| 끝나는 날이 지남 (서버 판정이 늦음) | `오늘까지 쓸 수 있어요`. 음수 날짜를 보이지 않는다 |
| 서버가 혜택 권한 3개를 모두 끔 | 알약 줄 없음 |
| 큰 글자, 긴 번역 | 큰 글 줄은 폭에 맞춰 줄고, 알약은 줄바꿈, 버튼은 세로 |

## 검증

- `flutter analyze`, `tool/check_design_rules`, `check_layer_imports`, `check_unused_code`, `check_hangul_literals`
- 실제 위젯 렌더 캡처: 선물, 스토어 구독, 체험, 기간 제한 없음, 마지막 날, 큰 글자 1.6배, 영어, 태블릿 세로, 내 정보 카드
- 앱 테스트는 두지 않는다 (#848)

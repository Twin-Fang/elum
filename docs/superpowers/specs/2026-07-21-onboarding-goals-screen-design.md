# 온보딩_목표 화면 Figma 정합 설계

> 작성일: 2026-07-21
> 대상 Figma 프레임: `온보딩_목표` `204:1002` / `온보딩_목표_선택` `204:1147`
> 파일: `VSmGuv1iuOpLZmp6QeBHWr` (이룸)

## 배경

`GoalsScreen`은 이미 존재하지만 Figma 원본과 다르게 구현되어 있다.
Figma MCP로 두 프레임을 덤프해 비교한 결과 아래 불일치를 확인했다.
**재구현이 아니라 원본 정합 맞추기**가 이 작업의 내용이다.

`온보딩_이름` 화면은 **다른 세션이 동시에 작업 중**이므로 이 작업에서 건드리지 않는다.
공유 파일(`app_colors.dart`, `app_assets.dart`)을 수정하므로 충돌 지점을 아래에 명시한다.

## Figma 덤프에서 확인한 실제 값

### 프레임 공통 (393×852)

| 요소 | 값 |
| --- | --- |
| 배경 | `#F7F2EF` |
| 뒤로가기 | `fi-br-angle-left` SVG 24×24, x=24 y=75 |
| 제목 | `하늘이의 어떤 순간을\n도와주고 싶으신가요?` 28/w800 `#242634`, x=24 y=131 |
| 설명 | `여러 개를 선택할 수 있어요` 16/w400 `#898B98`, x=24 y=211 |
| CTA | 360×66 r18, x=16 y=675 |

### 칩 4개 — 좌표

| # | 목표 | 칩 y | 아이콘 y | 텍스트 y |
| --- | --- | --- | --- | --- |
| 1 | 해야 할 일을 순서대로 이해해요 | 279 | 293 | 305 |
| 2 | 필요한 준비물을 스스로 챙겨요 | 365 | 379 | 391 |
| 3 | 새로운 상황을 미리 준비해요 | 451 | 465 | 477 |
| 4 | 혼자 끝까지 해내는 경험을 만들어요 | 537 | 551 | 563 |

- 칩: **344×68 r20**, x=24 → 간격 **86px** (= 68 + 18)
- 아이콘: **40×40**, x=38 → 칩 좌측 내부 여백 14px, 세로 중앙(칩 y+14)
- 텍스트: 16/w400 **`#000000`**, x=90 → 아이콘 우측 12px

> 텍스트 색이 `#000000`이다. `textPrimary`(`#242634`)가 **아니다.**

### 선택 상태 (`204:1147`)

| 상태 | 배경 | 테두리 |
| --- | --- | --- |
| 미선택 | `#FFFFFF` | `#EFEFEF` 1px |
| 선택 | `#B5EAEC` | `#93DBCC` **2px** |

CTA는 미선택 프레임에서 `disable`(`187:291`), 1개 이상 선택 시 `enable`(`187:300`).

### 아이콘 — 중요

`Group 5`~`Group 8`(`204:1161`/`1164`/`1167`/`1170`)이 **네 개 모두 동일한 구성**이다.

```
Ellipse 1        40×40, fill rgba(255, 214, 41, 0.3)   ← 노란 반투명 원
fi-br-child-head 24×24 @ (8,8), 인스턴스 187:505       ← 아이 얼굴 아이콘
```

즉 **목표별로 아이콘이 다르지 않다.** 현재 코드는 `goal_step_by_step.svg` 등
4개를 목표별로 매핑하고 있어 원본과 어긋난다.

또한 아이콘 배경 원은 **선택 여부와 무관하게 동일**하다
(미선택 프레임 `fill_ZEETS2`, 선택 프레임 `fill_X1YVYK` 둘 다 `rgba(255,214,41,0.3)`).
칩 배경만 흰색↔민트로 바뀐다.

## 결정 사항

| 항목 | 결정 | 근거 |
| --- | --- | --- |
| 목표 아이콘 | **단일 에셋 1개**로 통일 | Figma가 원본. 덤프에 4종 구분이 없다 |
| 색 토큰 | `selectedFill`/`selectedBorder` **제거**, 용도별 분리 | 목표·여우·고양이 색이 서로 다르다 |
| 작업 범위 | 목표 화면 + 색 토큰 + 문서 | 캐릭터 화면은 색 토큰 변경에 따른 **연쇄 수정만** |

> 목표별 아이콘 차별화가 UX상 나은지는 디자이너 확인이 필요하다. 이슈에 남긴다.

## 설계

### 1. 색 토큰 (`core/theme/app_colors.dart`)

`selectedFill` / `selectedBorder` 단일 쌍을 제거하고 용도별로 나눈다.
남겨두면 "어느 쪽을 써야 하는가"가 모호해져 다음 사람이 잘못 고른다.

```dart
// 목표 칩 — Figma 204:1147
final Color goalSelectedFill;    // #B5EAEC
final Color goalSelectedBorder;  // #93DBCC

// 캐릭터 카드 — 캐릭터마다 다르다 (Figma 204:1121 / 204:1134)
final Color foxSelectedFill;     // #FFDAC7
final Color foxSelectedBorder;   // #EB9B73
final Color catSelectedFill;     // #CED8FF
final Color catSelectedBorder;   // #9CADF1
```

캐릭터 색은 `CardCharacter` enum과 1:1이므로 `switch` 매핑 헬퍼를 둔다.
`AppAssets.character()`와 같은 패턴이며, **새 캐릭터 추가 시 컴파일 에러로 잡힌다.**

```dart
// AppColors 확장 — enum이 늘면 여기서 터진다
(Color fill, Color border) characterSelected(CardCharacter c) => switch (c) {
      CardCharacter.fox => (foxSelectedFill, foxSelectedBorder),
      CardCharacter.cat => (catSelectedFill, catSelectedBorder),
    };
```

선택 테두리 두께 2px는 목표·캐릭터 공통이므로 `AppSpacing.selectedBorderWidth`로 둔다.

### 2. 에셋 (`core/assets/app_assets.dart`)

```dart
// 함수 → 상수. 목표별로 다르지 않다.
static const goalIcon = '$_images/goal_icon.svg';

/// 뒤로가기 (24×24). Figma fi-br-angle-left.
static const iconBack = '$_images/icon_back.svg';
```

기존 `goalIcon(SupportGoal)` 함수와 `goal_*.svg` 4개는 **삭제**한다.
(파일 삭제는 사용자 확인 후 진행)

### 3. 칩 위젯 (`goal_chip.dart`)

Figma 좌표를 그대로 반영한다. padding 근사가 아니라 실측값이다.

```
높이       68 (고정)
radius     20
아이콘      40×40, 좌측 14
텍스트      좌측 12 (아이콘 기준), 16/w400 #000000
칩 간격     18 (다음 칩 y - 현재 칩 높이)
```

`AnimatedContainer` 200ms는 유지한다 — 아동도 보는 화면이라 급한 전환을 쓰지 않는다.
(client/CLAUDE.md 아동 모드 규칙)

### 4. 화면 (`goals_screen.dart`)

구조는 유지하되 아래를 맞춘다.

- 칩 간격을 `space.sm`(12) → Figma 18로
- `SelectableGroup`의 기본 `Column`을 그대로 쓴다 (세로 리스트가 맞다)
- CTA 활성 조건은 기존 `canProceedFromGoals`(1개 이상) 유지 — Figma와 일치

### 5. 뒤로가기 (`elum_scaffold.dart`)

Material `Icons.arrow_back_ios_new` → Figma SVG(`AppAssets.iconBack`)로 교체.
이 변경은 온보딩 전 화면에 영향을 준다. **온보딩_이름 세션과 겹치는 지점이다.**

## 서버 연동

이 화면이 수집한 값은 온보딩 완료 시점에 서버로 보낸다.

```
PATCH /api/member/support-goals
{ "supportGoals": ["STEP_BY_STEP" | "PREPARE_ITEMS" | "PREPARE_NEW" | "INDEPENDENT"] }
```

Swagger(`https://api.elum.chuseok22.com/v3/api-docs`)로 확인한 결과
클라이언트 `SupportGoal.apiValue` 4개 값이 **서버와 정확히 일치**한다. 수정 불필요.

> 이번 작업 범위는 화면까지다. 실제 API 호출은 온보딩 완료(`complete()`) 단계에서
> 붙이며 별도 이슈로 다룬다.

## 테스트

`test/goals_screen_test.dart`를 **구현 전에** 작성한다.

| 검증 | 이유 |
| --- | --- |
| 목표 4개가 Figma 문구 그대로 렌더링된다 | 문구는 서비스 정체성이다 |
| 미선택 시 CTA가 비활성이다 | Figma `disable` variant |
| 1개 선택하면 CTA가 활성된다 | Figma `enable` variant |
| 선택 칩 배경이 `goalSelectedFill`이다 | 색을 캐릭터색으로 잘못 쓴 전례가 있다 |
| 아이콘을 SVG로 렌더링한다 | 도형을 코드로 그리지 않았는지 (트러블슈팅 사고 3건) |
| 다중 선택이 된다 | Figma 설명 문구 "여러 개를 선택할 수 있어요" |

`ScreenUtilInit` + `testStorageOverride` 헬퍼를 쓴다. 골든은 사용자 눈 승인 후 생성한다.

## 문서 갱신

### `client/CLAUDE.md`

"디자인·API 원본 위치" 섹션을 신설한다.

- Figma fileKey `VSmGuv1iuOpLZmp6QeBHWr`, 온보딩 루트 섹션 `238:3022`
- Swagger `https://api.elum.chuseok22.com/v3/api-docs`
- 서버 내부 로직은 `server/src/main/java/com/chuseok22/elumserver/**`
- **규칙**: Figma URL을 받으면 해당 노드를 직접 덤프한다. 덤프와 `docs/`가 다르면
  **덤프가 기준**이고 문서를 고친다. 덤프에 없는 값을 추측해 채우지 않는다.

CLAUDE.md는 이미 360줄이라 노드 ID 표는 넣지 않고 `onboarding-flow.md`로 링크한다.

### `client/docs/onboarding-flow.md`

프레임 노드 ID 표를 **실측값으로 정정**한다. 기존 문서는 자식 노드 ID를
프레임 ID로 잘못 적어놨다.

| 프레임 | 문서에 적힌 값 | 실제 프레임 ID |
| --- | --- | --- |
| 온보딩_목표 | `204:1009` (CTA 버튼 인스턴스) | **`204:1002`** |
| 온보딩_비밀번호 | `238:1912` (CTA 버튼 인스턴스) | **`238:1909`** |

전체 표는 아래로 교체한다.

| 프레임 | 노드 ID | 라우트 |
| --- | --- | --- |
| 시작 | `238:1808` | `/` |
| 온보딩_이름 | `204:991` | `/onboarding/name` |
| 온보딩_이름 (입력됨) | `204:1174` | ↑ |
| 온보딩_목표 | `204:1002` | `/onboarding/goals` |
| 온보딩_목표_선택 | `204:1147` | ↑ |
| 온보딩_캐릭터 | `204:1029` | `/onboarding/character` |
| 온보딩_캐릭터_여우 | `204:1121` | ↑ |
| 온보딩_캐릭터_고양이 | `204:1134` | ↑ |
| 온보딩_비밀번호 | `238:1909` | `/onboarding/pin` |
| 온보딩_비밀번호_입력 | `238:1997` | ↑ |
| 온보딩_비밀번호_입력 (재확인) | `238:2767` | ↑ |
| 온보딩_비밀번호_완료 | `238:2924` | `/onboarding/done` |

### `client/docs/design-system.md`

선택 색 토큰 표를 목표·여우·고양이 3종으로 갱신한다.

## 다른 세션과의 충돌 지점

`온보딩_이름` 세션이 같은 파일을 만질 수 있다.

| 파일 | 이 작업의 변경 | 충돌 시 |
| --- | --- | --- |
| `app_colors.dart` | 선택 색 토큰 분리 | 이 작업 것이 기준 (Figma 덤프 근거) |
| `app_assets.dart` | `goalIcon` 함수→상수, `iconBack` 추가 | 양쪽 병합 |
| `elum_scaffold.dart` | 뒤로가기 SVG 교체 | 먼저 넣는 쪽 유지 |
| `onboarding-flow.md` | 노드 ID 표 정정 | 양쪽 병합 |

`name_screen.dart` / `onboarding-name-screen-design.md`는 **건드리지 않는다.**

## 미확정

- 목표별 아이콘 차별화 여부 (디자이너 확인 필요 — 현재 Figma는 4개 동일)
- `goal_*.svg` 4개 파일 삭제 시점 (사용자 확인 후)

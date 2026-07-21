# 카드확인 화면 배경 블러 글로우 제거

- 날짜: 2026-07-22
- 기준 Figma (2026-07-22 덤프):
  - `262:5124` 보호자_새로운 일과 만들기_카드확인 — 프레임 fill `#F7F2EF` **단색**, Gradient/블러 노드 없음
  - `238:3022` 온보딩 SECTION — 프레임 12개 모두 fill `#F7F2EF` 단색 (`시작` 238:1808만 그라데이션 + SVG)

## 문제

카드가 생성되어 카드확인 화면에 진입하면 배경에 컬러 블러 글로우가 계속 남는다.
Figma 262:5124의 배경은 단색 `#F7F2EF` 하나뿐이므로 시안과 어긋난다.

## 원인

`RoutineFlowScaffold`(`widgets/routine_flow_scaffold.dart:46`)가 **조건 없이**
`AuroraBackground`를 깐다. 이 위젯은 일과 만들기 흐름 4개 화면(입력·로딩·질문·카드확인)이
공유하므로, 입력 화면(238:1643의 Gradient 238:1728)을 재현하려고 만든 글로우가
카드확인 화면까지 새어 나왔다.

## 해결

`RoutineFlowScaffold`에 `showAurora` 플래그를 추가한다. 기본값은 `true`.

```dart
/// 배경 글로우를 그릴지. Figma에 Gradient가 없는 화면은 false로 끈다.
final bool showAurora;
```

`card_review_screen.dart`의 호출부 두 곳(정상 경로 · `_EmptyCards`)에서
`showAurora: false`를 넘긴다.

**기본값을 `true`로 두는 이유** — 입력·로딩·질문 화면은 현재 동작이 맞다.
예외인 화면만 명시적으로 끄면 다른 화면에 회귀가 생기지 않는다.
나중에 다른 화면도 Figma 대조 후 끄고 싶으면 한 줄이면 된다.

**배경색** — 스캐폴드가 이미 `context.colors.background`를 쓰므로 글로우만 빼면
단색이 드러난다. 이 값이 `#F7F2EF`인지 확인하고, 다르면 토큰을 맞춘다.

## 범위 밖

- 로딩·질문 화면의 글로우 — Figma 대조를 따로 하지 않았으므로 건드리지 않는다
- `AuroraBackground` 위젯 자체 — 입력 화면에서 계속 쓰인다

## 실패 경로

렌더링 분기이므로 런타임 실패 경로가 없다. 위젯 트리에서 `AuroraBackground`가
빠질 뿐이고, 배경색은 `Scaffold.backgroundColor`가 항상 채운다.

## 검증

- 위젯 테스트: 카드확인 화면 위젯 트리에 `AuroraBackground`가 **없음**을 확인
- 위젯 테스트: 입력 화면에는 **있음**을 확인 (회귀 방지)
- 기존 카드확인 테스트 통과
- `flutter analyze` / `flutter test`
- 시뮬레이터 화면과 Figma 262:5124 PNG 비교

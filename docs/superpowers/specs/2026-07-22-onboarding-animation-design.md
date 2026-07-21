# 온보딩 애니메이션 개선 — 시작 화면 연출 + 전환 통일 설계

- 날짜: 2026-07-22
- 대상 Figma: `238:3022` 온보딩 SECTION, 특히 `238:1808` 시작 프레임
- 관련 문서: [client/docs/motion.md](../../../client/docs/motion.md) · [client/docs/onboarding-flow.md](../../../client/docs/onboarding-flow.md)

## 배경 · 문제

motion.md에 모션 규칙(AppMotion 토큰·페이지 전환·AppFadeSlideIn)이 정의돼 있지만
**온보딩에는 적용되지 않았다.**

| 현재 상태 | 문제 |
| --- | --- |
| 시작 화면(`splash_screen.dart`)이 완전히 정적 | 첫인상이 밋밋하다. 브랜드 핵심 순간인데 연출이 없다 |
| 온보딩 페이지 전환이 go_router 기본(즉시 교체) | motion.md "전환 없는 즉시 교체 금지" 위반. 딱딱해 보이는 주원인 |
| `AppFadeSlideIn`이 "도입 예정"인 채 미구현 | 화면 콘텐츠 등장 연출을 만들 공통 수단이 없다 |

## 목표

1. 시작 화면에 **등장 연출 + idle 모션**을 넣어 첫 장면의 완성도를 올린다
2. 온보딩 전 구간(시작→이름→목표→캐릭터→PIN→완료)의 **페이지 전환을 통일**한다
3. `AppFadeSlideIn`을 실제 구현해 이후 화면에서도 재사용할 수 있게 한다

**비목표**: 보호자·아동 모드 화면의 모션 적용(별도 작업), 새 패키지 도입.

## 접근법 (확정: A안)

**새 패키지 없이 Flutter 기본 API + AppMotion 토큰으로 자체 구현한다.**

- 검토한 대안: `animations` 패키지(SharedAxis) — 검증된 질감이지만 analyzer 충돌 전례가
  있는 레포에 의존성 리스크가 있고, duration·curve가 패키지 내부값이라 토큰과 이원화된다.
- go_router 전역 기본 전환만 교체하는 안 — 화면별 등장 연출이 없어 목표에 못 미친다.

## 설계

### 1. 시작 화면 연출 (`splash_screen.dart`)

**원칙: 장면(병아리·덤불·별·실루엣·배경)은 첫 프레임부터 완성돼 있다.**
뒤늦게 뜨면 "덜 로드된 느낌"이 난다. 그 위에 텍스트 요소만 차분하게 등장한다.

#### 등장 연출 (일회성, 총 ~540ms)

| 순서 | 요소 | 지연 | 모션 |
| --- | --- | --- | --- |
| — | 병아리·덤불·별·실루엣·배경 | 없음 | **처음부터 표시** |
| 1 | "오늘의 하루," + "차근차근 함께해요" | 0ms | fade + slide up (`AppFadeSlideIn`) |
| 2 | 로고 SVG | 120ms | fade + slide up |
| 3 | CTA 버튼 + "secured by ELUM AI DLP" | 240ms | fade + slide up |

- 각 요소 duration은 `AppMotion.normal`(300ms) + `entry` curve
- 지연 간격 120ms는 `AppMotion`에 **`sceneStagger` 토큰으로 추가**한다
  (기존 `staggerDelayMs` 30ms는 리스트용 — 장면 연출은 단위가 다르다)
- CTA는 등장 중에도 터치 가능하다 (540ms 안에 끝나므로 실사용 충돌 없음)

#### idle 모션 (반복)

| 요소 | 모션 | 주기 |
| --- | --- | --- |
| 병아리 몸통 | scale 1.0 ↔ 1.015 (숨쉬기, `Alignment.bottomCenter` 기준) | 3.4s |
| 별 | opacity 1.0 ↔ 0.55 (반짝임) | 2.6s |

- 주기 3.4s·2.6s는 서로 배수가 아니다 (motion.md 성능 규칙 — 패턴이 눈에 안 보이게)
- 주기 값은 **splash 전용 안무 값**이므로 화면 내 private 상수로 두고 WHY 주석을 남긴다.
  전 화면 공용 토큰(AppMotion)에 넣지 않는 이유: 다른 화면과 공유될 값이 아니고,
  배수 회피를 화면 단위로 조율해야 하는 값이라서다.
- 반복 요소는 `RepaintBoundary`로 격리한다

#### 접근성 · 실패 경로

| 상황 | 동작 |
| --- | --- |
| OS "동작 줄이기" 켜짐 (`MediaQuery.disableAnimationsOf`) | idle 컨트롤러를 **생성/시작하지 않는다** (정적 표시). 일회성 등장은 유지 |
| 등장 지연 중 화면 이탈 | delay 타이머·컨트롤러를 `dispose()`에서 정리, `mounted` 가드 |
| 위젯 테스트 | 반복 컨트롤러 때문에 `pumpAndSettle`이 끝나지 않는다 → 테스트는 `disableAnimations`를 켜거나 고정 시간 `pump`를 쓴다 |

`SplashScreen`은 `ConsumerWidget` → `ConsumerStatefulWidget`으로 바꾼다
(idle 컨트롤러 필요 — client/CLAUDE.md의 "애니메이션 컨트롤러가 필요할 때만" 예외에 해당).

### 2. `AppFadeSlideIn` 공통 위젯 (신규)

`lib/core/widgets/app_fade_slide_in.dart`

```
AppFadeSlideIn(
  delay: Duration,          // 기본 Duration.zero — stagger용
  duration: Duration,       // 기본 AppMotion.normal
  curve: Curve,             // 기본 AppMotion.entry
  offset: double,           // 기본 16 — 아래에서 올라오는 거리(논리 px)
  child: Widget,
)
```

- opacity 0→1 + `Transform.translate` 아래→제자리
- 내부 `AnimationController` 1개. `delay`는 `Timer`가 아니라 컨트롤러 시작을 늦추는
  방식으로 처리하고, `dispose()` 시 정리한다 (dispose 후 setState 사고 방지)
- 등장 후에는 오버헤드가 없도록 완료 시 child만 남긴다

### 3. 온보딩 페이지 전환

`lib/core/router/app_transitions.dart` (신규)에 헬퍼를 만들고, `app_router.dart`의
온보딩 라우트를 `builder` → `pageBuilder`로 바꾼다.

| 구간 | 전환 | 토큰 |
| --- | --- | --- |
| 이름 ↔ 목표 ↔ 캐릭터 ↔ PIN ↔ 완료 | 수평 슬라이드 + fade (들어오는 화면이 오른쪽에서) | `AppMotion.slow`(400ms) + `decelerate` |
| 시작 → 이름 | 위와 동일 (온보딩 진입) | 동일 |
| 완료 → 보호자 홈 | fade (motion.md "시작 화면 → 홈" 규칙 준용) | `AppMotion.slow` + `standard` |

- 뒤로가기(pop)는 go_router가 같은 전환을 역재생하므로 **자동으로 역방향**이 된다
- 헬퍼 시그니처: `slidePage(child)` · `fadePage(child)` — `CustomTransitionPage` 반환
- go_router 전환은 **목적지 라우트**가 결정하므로, "완료 → 보호자 홈" fade는
  `Routes.guardian` 라우트에 `fadePage`를 적용해 구현한다. 이러면 다른 경로에서
  보호자 홈으로 갈 때도 fade가 걸리는데, 즉시 교체보다 나으므로 허용한다
- 그 외 라우트(아동 모드·일과 생성 등)는 이번 작업에서 건드리지 않는다

### 4. 문서 갱신

`client/docs/motion.md` 적용 현황 표를 갱신한다
(AppFadeSlideIn 구현됨 · 페이지 전환 온보딩 구간 적용됨 · 갱신 날짜 명기).

## 테스트 계획

| 층 | 테스트 | 확인 내용 |
| --- | --- | --- |
| 위젯 | `app_fade_slide_in_test.dart` (신규) | 시작 시 투명 → `duration+delay` 경과 후 완전 표시. dispose 후 예외 없음 |
| 위젯 | `splash_screen_test.dart` (수정) | 기존 테스트(SVG 렌더링 등) 유지 통과. 등장 완료 후 문구·CTA 표시. `disableAnimations` 켜도 정상 렌더 |
| 위젯 | 라우터 테스트 | 온보딩 라우트가 `CustomTransitionPage`를 쓰는지, pop이 동작하는지 |
| 골든 | 기존 골든 | 등장 완료 시점 기준으로 유지 (필요 시 고정 시간 pump 후 캡처) |

기존 스플래시 위젯 테스트가 `pumpAndSettle`을 쓰고 있다면 idle 반복 때문에 멈추지
않는 문제가 생긴다 — 테스트 헬퍼에서 `disableAnimations`를 켜는 방식으로 해결한다.

## 작업 파일 목록

| 파일 | 변경 |
| --- | --- |
| `client/lib/core/theme/app_motion.dart` | `sceneStagger` 토큰 추가 |
| `client/lib/core/widgets/app_fade_slide_in.dart` | 신규 |
| `client/lib/core/router/app_transitions.dart` | 신규 — slidePage/fadePage 헬퍼 |
| `client/lib/core/router/app_router.dart` | 온보딩 라우트 pageBuilder 적용 |
| `client/lib/features/onboarding/presentation/splash_screen.dart` | 등장 연출 + idle 모션 |
| `client/docs/motion.md` | 적용 현황 갱신 |
| `client/test/…` | 위 테스트 계획 반영 |

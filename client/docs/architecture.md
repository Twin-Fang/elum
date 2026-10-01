# 클라이언트 아키텍처

> 스택 선정 이유는 [../CLAUDE.md](../CLAUDE.md) 참조. 이 문서는 **구조와 규칙**을 다룬다.

## 폴더 구조 (feature-first)

```
lib/
├── main.dart
├── app.dart                        # MaterialApp.router + ProviderScope
│
├── core/                           # 기능에 종속되지 않는 공통 코드
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   └── app_theme.dart
│   ├── router/
│   │   └── app_router.dart         # go_router 정의
│   ├── network/
│   │   ├── dio_client.dart
│   │   └── fallback_interceptor.dart   # AI 실패 시 fallback 체인
│   ├── storage/
│   │   └── local_storage.dart      # shared_preferences 래퍼
│   └── widgets/                    # 화면 간 재사용 위젯
│       ├── elum_button.dart        # 하단 CTA (360×66 r18)
│       ├── elum_text_field.dart    # 입력 필드 (344×68 r20)
│       └── elum_scaffold.dart      # 배경색 + SafeArea 공통 뼈대
│
├── features/
│   ├── onboarding/
│   │   ├── domain/                 # 모델 (Freezed)
│   │   ├── application/            # provider / notifier
│   │   └── presentation/           # 화면 + 화면 전용 위젯
│   ├── guardian/                   # 보호자 모드 (일과 입력·DLP·카드 검토·승인)
│   └── child/                      # 아동 모드 (카드 수행·TTS·별 보상)
│
└── shared/
    └── models/                     # feature 간 공유 모델 (ActionCard 등)
```

### 왜 feature-first인가

보호자 모드와 아동 모드는 **UI 규칙이 완전히 다르다** (터치 타겟, 애니메이션 속도, 텍스트 크기).
레이어 우선(`screens/`, `widgets/`)으로 나누면 두 모드의 위젯이 한 폴더에 섞여 규칙이 무너진다.

## 상태관리 — Riverpod

### 레이어 규칙

```
presentation  →  application  →  domain
   (위젯)         (notifier)      (모델)
                     ↓
                repository (network/storage)
```

- **위젯은 provider만 읽는다.** repository를 직접 부르지 않는다.
- **notifier는 위젯을 모른다.** `BuildContext`를 받지 않는다.

### 예시

```dart
// application/onboarding_notifier.dart
@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  OnboardingProfile build() => const OnboardingProfile.empty();

  // 호칭 입력 — CTA 활성화 여부는 위젯이 state를 보고 판단한다
  void setNickname(String v) => state = state.copyWith(childNickname: v);

  void toggleGoal(SupportGoal g) { /* 다중 선택 */ }
}
```

```dart
// presentation/name_screen.dart
class NameScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(onboardingNotifierProvider);
    return ElumScaffold(
      child: ElumButton(
        label: '다음',
        // 빈 값이면 비활성 — design-system.md의 disabled 토큰 적용
        onPressed: profile.childNickname.isEmpty ? null : () => context.go('/onboarding/goals'),
      ),
    );
  }
}
```

## 라우팅 — go_router

```dart
final routes = [
  GoRoute(path: '/',                    builder: SplashScreen.new),
  GoRoute(path: '/onboarding/name',     builder: NameScreen.new),
  GoRoute(path: '/onboarding/goals',    builder: GoalsScreen.new),
  GoRoute(path: '/onboarding/character',builder: CharacterScreen.new),
  GoRoute(path: '/onboarding/pin',      builder: PinScreen.new),
  GoRoute(path: '/onboarding/done',     builder: DoneScreen.new),
  GoRoute(path: '/guardian',            builder: GuardianHomeScreen.new),
  GoRoute(path: '/child',               builder: ChildHomeScreen.new),
];
```

**redirect 규칙**

- 온보딩 미완료 상태로 `/guardian` 진입 시 → `/onboarding/name`
- 아동 모드(`/child`)에서 보호자 모드로 나갈 때 → PIN 확인

> 아동 모드에서는 **시스템 뒤로가기를 막는다** (`PopScope`). 아동이 실수로 이탈하면 안 된다.

## 서버 연동

서버가 아직 없으므로 **repository 인터페이스를 먼저 정의하고 mock으로 구현**한다.

```dart
abstract interface class CardRepository {
  Future<List<ActionCard>> generateCards(RoutineRequest req);
}

// 서버 준비 전 — 데모 시나리오 고정 응답
class MockCardRepository implements CardRepository { ... }

// 서버 준비 후 — provider만 갈아끼운다
class RemoteCardRepository implements CardRepository { ... }
```

```dart
@riverpod
CardRepository cardRepository(Ref ref) => MockCardRepository();  // ← 한 줄 교체
```

### fallback 체인 (필수)

루트 docs 원칙 6번: **데모는 어떤 실패 상황에서도 끝까지 진행되어야 한다.**

```
1차: 서버 API 호출
2차: 서버 실패 → 클라이언트 내장 기본 카드 세트
3차: 파싱 실패 → 하드코딩된 데모 카드 5장
```

어느 단계에서 실패했든 **사용자에게는 동일한 화면**이 보여야 한다.
에러 다이얼로그를 띄우지 않는다 — 발표 중 치명적이다.

## 로컬 저장

| 키 | 타입 | 비고 |
| --- | --- | --- |
| `childNickname` | String | 실명 아님 |
| `supportGoals` | List\<String\> | enum name |
| `characterType` | String | |
| `guardianPin` | String | ⚠️ `flutter_secure_storage` 권장 |
| `onboardingCompleted` | bool | redirect 판단용 |

> **보호자가 입력한 일과 원문은 로컬에도 남기지 않는다.** (루트 docs 원칙 5번)

## 광고 (AdMob, #281)

`lib/core/ads/`가 광고를 전담한다. 화면은 `AdBannerSlot` 하나만 안다.

| 파일 | 역할 |
|---|---|
| `ad_ids.dart` | 배치(`AdPlacement`)·플랫폼별 광고 단위 ID. **테스트 모드면 `.env`를 읽지 않는다** |
| `ad_gate.dart` | `adsEnabledProvider` — 모바일이고 서버 `entitlements.adsRemoved`가 false일 때만 켜짐(Pro는 꺼짐). 요금제를 모르면(조회 중·실패) 광고를 요청하지 않는다 |
| `ad_consent.dart` | iOS ATT 요청, 거부·실패면 비개인화 |
| `ad_banner_loader.dart` | 로더 인터페이스와 google_mobile_ads 구현. 테스트는 가짜로 바꾼다 |
| `ad_banner_slot.dart` | 로드 전·실패 시 **높이 0**, 성공하면 그 높이만큼 본문이 줄어든다 |

지켜야 할 것.

- **광고를 import할 수 있는 화면은 보호자 홈·임시저장뿐이다.** 설정은 맨 아래 `회원탈퇴` 줄과 가까워 광고를 뺐다. 이룸이 화면·일과 만들기
  흐름·보상 연출·온보딩에는 광고 코드가 닿지 않는다. `test/ads/ad_boundary_test.dart`가 잠근다.
- `google_mobile_ads`는 `core/ads` 안에서만 쓴다. 광고 요청에는 `nonPersonalizedAds` 외 사용자 정보를 넘기지 않는다.
- **개발·디버그·프로필·dev 빌드는 Google 테스트 광고 단위만 쓴다**(`AppConfig.useTestAds`). 실제 ID는
  릴리스 빌드의 `.env`로만 들어간다. 개발 중 실제 광고를 누르면 AdMob 계정이 정지될 수 있다.
- 하단 배너는 `ElumScaffold.bottomBanner`로 둔다. 홈의 목록 한가운데(오늘 일과와 지난 일과 사이)에는 배너를 두지 않는다 — 앱 디자인을 해쳐 뺐다. `AdBannerSlot.padding`은 광고가 뜬 뒤에만 적용돼 광고가 없으면 자리가 0이다. `bottomButton`·`belowButton`과 함께 쓰면 assert로 막힌다.
- **`google_mobile_ads`는 `^7.0.0`(광고 SDK iOS 12.14)으로 고정한다.** 9.x(iOS 13.7)는 Xcode 26 미만에서
  `Include of non-modular header inside framework module` 오류로 iOS 빌드가 실패한다(로컬 Xcode 16.2에서 확인).
  Xcode 26 이상만 쓰게 되면 올려도 된다.
- 광고 단위·앱 ID 발급 내역은 이슈 #281 마지막 댓글, 설계는 `docs/superpowers/specs/2026-09-30-admob-ads-design.md`.

## 코드 생성

Freezed / Riverpod / json_serializable은 코드 생성이 필요하다.

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch   # 개발 중 권장
```

생성 파일(`*.freezed.dart`, `*.g.dart`)은 **커밋한다** — CI에서 생성 단계를 빼기 위함.

## 미확정 사항

- 서버 base URL · 인증 방식 (MVP는 로그인 제외)
- `ActionCard` 모델 필드 확정 (→ [../../docs/06-api-spec.md](../../docs/06-api-spec.md))
- DLP 전/후 비교 화면의 데이터 형식
- 아동 모드 TTS 음성 종류·속도

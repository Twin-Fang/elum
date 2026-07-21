# 이룸(ELUM) 클라이언트 아키텍처 설계

> 작성일: 2026-07-21
> 관련 이슈: [#1](https://github.com/Twin-Fang/elum/issues/1)
> 상태: 승인됨 — 기본 init 범위

## 배경

`client/`는 `flutter create` 직후 상태였다. Figma 온보딩 디자인(node `238:3022`, 프레임 12개)을 구현하기 전에
**앞으로 유지보수할 것을 전제로** 기반 구조를 확정한다.

24시간 해커톤이지만 대회 이후에도 이어갈 레포이므로, 단기 속도보다 **경계가 분명한 구조**를 우선한다.

## 설계 결정

| 항목 | 결정 | 근거 |
| --- | --- | --- |
| 디자인 토큰 | **ThemeExtension** (Flutter 정석) | 다크/아동 테마 확장 대비. 보일러플레이트는 초기 1회 비용 |
| 선택 컴포넌트 | **로직만 공통** (`SelectableGroup<T>`) | 목표 칩과 캐릭터 카드의 생김새가 독립적으로 변할 수 있어야 함 |
| 아동 모드 | **별도 위젯 트리** | 접근성 규칙을 타입 수준에서 강제. 보호자용 위젯 오용 방지 |
| 실패 처리 | **Repository에서 흡수** | UI가 실패를 모르게 함 → 발표 중 에러 화면이 구조적으로 불가능 |
| 상태관리 | Riverpod + go_router + Freezed | 서버 미완성 구간을 mock으로 대체하기 쉬움 |

### 공통화 기준

**실제로 2회 이상 반복된 것만** 공통 위젯으로 분리한다.

화면 하나만 보고 공통화하면 두 번째 화면에서 파라미터가 계속 붙어
`ElumButton(isSmall: true, hasIcon: true, ...)` 같은 것이 된다.
`presentation/widgets/`에 두었다가 두 번째 화면이 필요로 할 때 `core/widgets/`로 승격한다.

## 디자인 토큰 (Figma 실측값)

> ⚠️ 초기 조사에서 버튼 enabled 색을 `#FF8B22`로 **추론**했으나 오류였다.
> 컴포넌트셋 `187:299`의 variant를 직접 조회해 실제 값으로 정정했다.

### 색상

| 토큰 | HEX | 용도 |
| --- | --- | --- |
| `background` | `#F7F2EF` | 화면 배경 |
| `surface` | `#FFFFFF` | 카드·입력 필드 |
| `textPrimary` | `#242634` | 제목·본문 |
| `textSecondary` | `#898B98` | 보조 설명 |
| `textPlaceholder` | `#DADADA` | placeholder |
| `border` | `#EFEFEF` | 기본 테두리 1px |

### 버튼 (컴포넌트셋 `187:299` — 360×66, r18, 22/w800)

| 상태 | 배경 | 텍스트 |
| --- | --- | --- |
| `enable` | **`#242634`** | `#FFFFFF` |
| `disable` | `#818393` | `rgba(255,255,255,0.5)` |

### 선택 상태 (목표 칩 · 캐릭터 카드 공통)

| 상태 | 배경 | 테두리 |
| --- | --- | --- |
| 미선택 | `#FFFFFF` | `#EFEFEF` 1px |
| **선택** | **`#FFDAC7`** | **`#EB9B73` 2px** |

### 타이포그래피 — `TmoneyRoundWind`

| 토큰 | size | weight | lineHeight | 용도 |
| --- | --- | --- | --- | --- |
| `title` | 28 | w800 | 1.2 | 화면 제목 (2줄) |
| `button` | 22 | w800 | 1.0 | 하단 CTA |
| `input` | 20 | w400 | 1.0 | 입력 필드 |
| `body` | 16 | w400 | 1.0 | 설명·칩 텍스트 |

`Cloudsofa_namgim`(로고 64px)은 파일 미확보 → 로고는 이미지 에셋으로 처리한다.

### 온보딩 공통 수직 리듬 (393×852)

```
y=131   제목      (24 좌여백, height 68)
y=211   설명 문구
y=279   콘텐츠 시작 (입력필드 344×68 / 선택카드 176×202)
y=675   하단 CTA  (16 좌여백, 360×66)
```

## 캐릭터 모델링

**두 캐릭터의 역할이 다르므로 타입을 분리한다.**

| | 고양이 / 여우 | 병아리 |
| --- | --- | --- |
| 역할 | 아이가 고르는 **친구** | **에이전트 AI** (서비스 화자) |
| 등장 위치 | 생성된 **행동 카드 속 주인공** | **채팅**(카드 생성 대화) 화면 |
| 선택 여부 | 사용자가 온보딩에서 선택 | 고정 — 선택 대상 아님 |

```dart
/// 아이가 선택하는 카드 속 주인공
enum CardCharacter { cat, fox }

/// 서비스 에이전트 — 채팅에서 아이/보호자에게 말을 건다
enum AgentPersona { chick }
```

하나의 `CharacterType`으로 묶으면 "선택 가능한 것"과 "고정 화자"가 뒤섞여
카드 생성 로직에서 병아리가 주인공으로 들어가는 버그가 가능해진다.

**이번 범위**: enum 정의와 폴더 자리만 잡는다. 병아리 말풍선 위젯은 채팅 화면 구현 시
Figma를 보고 만든다 (온보딩엔 등장하지 않으므로 추측으로 미리 만들지 않는다).

## 폴더 구조

```
lib/
├── main.dart
├── app.dart                          # ProviderScope + MaterialApp.router
│
├── core/
│   ├── theme/
│   │   ├── app_colors.dart           # ThemeExtension<AppColors>
│   │   ├── app_typography.dart       # ThemeExtension<AppTypography>
│   │   ├── app_spacing.dart          # ThemeExtension<AppSpacing>
│   │   ├── app_theme.dart            # ThemeData 조립 + extensions 등록
│   │   └── theme_context_ext.dart    # context.colors / context.typo / context.space
│   ├── router/app_router.dart
│   ├── storage/                      # SharedPreferences + SecureStorage(PIN)
│   ├── network/dio_client.dart
│   └── widgets/                      # 보호자·공용 (2회 이상 반복된 것만)
│       ├── elum_scaffold.dart
│       ├── elum_header.dart
│       ├── elum_button.dart
│       ├── elum_text_field.dart
│       ├── selectable_group.dart
│       ├── agent/                    # 병아리 — 채팅 구현 시 채움
│       └── child/                    # 아동 전용 — 아동 모드 구현 시 채움
│
├── features/
│   ├── onboarding/
│   │   ├── domain/                   # OnboardingProfile, SupportGoal, CardCharacter
│   │   ├── application/              # OnboardingNotifier
│   │   ├── data/                     # OnboardingRepository
│   │   └── presentation/
│   │       ├── name_screen.dart
│   │       ├── goals_screen.dart
│   │       ├── character_screen.dart
│   │       ├── pin_screen.dart
│   │       └── widgets/              # 화면 전용
│   ├── guardian/                     # 폴더만 (이번 범위 밖)
│   └── child/                        # 폴더만 (이번 범위 밖)
│
└── shared/models/                    # ActionCard 등 feature 간 공유
```

## 테마 구현

```dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background, surface, textPrimary, textSecondary, textPlaceholder;
  final Color border, buttonEnabled, buttonEnabledText, buttonDisabled, buttonDisabledText;
  final Color selectedFill, selectedBorder;

  static const light = AppColors(
    buttonEnabled: Color(0xFF242634),
    selectedFill: Color(0xFFFFDAC7),
    selectedBorder: Color(0xFFEB9B73),
    // ...
  );

  @override AppColors copyWith({...});
  @override AppColors lerp(AppColors? other, double t);
}
```

접근은 `context` 확장으로 짧게 유지한다:

```dart
extension ThemeContextExt on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppTypography get typo => Theme.of(this).extension<AppTypography>()!;
  AppSpacing get space => Theme.of(this).extension<AppSpacing>()!;
}
```

동시에 표준 `ThemeData` 슬롯(`scaffoldBackgroundColor`, `textTheme`)에도 매핑해
기본 Flutter 위젯이 별도 설정 없이 올바르게 렌더링되게 한다.

## SelectableGroup — 로직만 공통

```dart
/// 선택 "상태"만 관리한다. 생김새는 itemBuilder가 전적으로 책임진다.
/// 목표 칩(다중)과 캐릭터 카드(단일)가 이 하나를 공유하되 서로 다르게 생길 수 있다.
class SelectableGroup<T> extends StatelessWidget {
  final List<T> items;
  final Set<T> selected;
  final bool multiSelect;
  final ValueChanged<Set<T>> onChanged;
  final Widget Function(BuildContext, T item, bool isSelected) itemBuilder;
}
```

## 데이터 흐름 · fallback

```
presentation → application(Notifier) → data(Repository) → network/storage
                                            ↑ fallback을 여기서 전부 흡수
```

```dart
abstract interface class CardRepository {
  /// 절대 throw하지 않는다. 어떤 실패에도 카드를 반환한다.
  Future<List<ActionCard>> generateCards(RoutineRequest req);
}
```

3단계 체인: **서버 → 목표 반영 기본 세트 → 하드코딩 데모 카드**.
각 단계 전환 시 `debugPrint`로 남기되 릴리스에선 무음. UI는 에러 분기를 쓸 일이 없다.

MVP 단계에서는 `MockCardRepository`를 주입하고, 서버 준비 시 provider 한 줄만 교체한다.

## 서버 계약 (server/ 실제 코드 기준)

**API 필드·enum은 추측하지 않는다.** `docs/06-api-spec.md`는 초안이며 서버 코드가 기준이다.

초기 설계에서 `supportGoals` enum을 문서 초안대로 적었다가 서버와 어긋난 것을 발견해 정정했다.

| 클라이언트 | 서버 출처 | 값 |
| --- | --- | --- |
| `SupportGoal` | `member/infrastructure/entity/SupportGoal.java` | `STEP_BY_STEP` / `PREPARE_ITEMS` / `PREPARE_NEW` / `INDEPENDENT` |
| `ActionCard` | `routine/infrastructure/entity/RoutineStep.java` | `id` / `description` / `stepOrder` / `imagePath` / `completed` |

엔드포인트: `/api/auth` (signup·login), `/api/member` (me·nickname·support-goals),
`/api/routines` (생성·questions·조회·revise·confirm·steps 완료/취소)

계약이 어긋나면 조용히 실패하므로 `test/onboarding_profile_test.dart`에 검증 테스트를 둔다.

## 온보딩 도메인 모델

```dart
@freezed
class OnboardingProfile with _$OnboardingProfile {
  const factory OnboardingProfile({
    @Default('') String childNickname,
    @Default({}) Set<SupportGoal> supportGoals,
    CardCharacter? cardCharacter,
    @Default('') String guardianPin,
  }) = _OnboardingProfile;

  const OnboardingProfile._();

  // 진행 조건을 모델이 스스로 안다 — 화면마다 재구현하지 않는다
  bool get canProceedFromName => childNickname.trim().isNotEmpty;
  bool get canProceedFromGoals => supportGoals.isNotEmpty;
  bool get canProceedFromCharacter => cardCharacter != null;
}
```

수집 정보는 **호칭 / 도움 목표 / 카드 캐릭터 / PIN** 4개뿐이다.
필드 추가 시 "진단명 없는 개인화" 원칙을 깨는지 먼저 검토한다.

보호자 입력 원문은 로컬에도 저장하지 않는다.

### PIN 저장 — 미해결

`flutter_secure_storage`를 쓰려 했으나, 의존하는 `objective_c`의 build hook이
Dart 3.10에서 `build_runner`의 AOT 컴파일을 깨뜨려 제외했다
(`dart compile aot-snapshot`이 build hook을 가진 프로젝트를 거부한다).

**현재 PIN은 `shared_preferences`에 평문 저장된다.** 보안 해커톤 특성상 지적 대상이므로
발표 전 재검토가 필요하다. `LocalStorage.setPin`/`getPin`으로 감싸두어
저장 방식을 바꿔도 호출부는 건드리지 않는다.

### 의존성 제약

`riverpod_generator`와 `json_serializable`도 `flutter_riverpod 3.3.2`의 analyzer 제약과
충돌해 제외했다. provider는 손으로 선언하고, JSON 파싱은 모델에 직접 쓴다.
Freezed는 정상 동작한다.

## 테스트 전략

| 대상 | 방법 |
| --- | --- |
| `OnboardingProfile` 진행 조건 | 순수 단위 테스트 |
| fallback 3단계 | 실패 주입 → **항상 카드 반환** 검증 (데모 성립 조건) |
| `SelectableGroup` 단일/다중 | 위젯 테스트 |
| 온보딩 플로우 | 통합 테스트 |

## 이번 init 범위

**포함**: 의존성, `core/theme` 전체, 공통 위젯 뼈대, 라우터, 저장소, 온보딩 도메인 모델, 폴더 구조

**제외** (개별 작업으로 진행): 온보딩 5개 화면 UI 구현, 채팅/병아리 위젯, 보호자 모드, 아동 모드

## 미확정 사항

- 목표 칩 아이콘 SVG 에셋 (Figma `Group 5~8` — 미추출)
- 캐릭터 일러스트 SVG 에셋 (고양이 `187:853`, 여우 `217:1649` — 미추출)
- 서버 base URL · `ActionCard` 필드 확정
- PIN 재입력 불일치 시 문구
- 온보딩 완료 후 진입 지점 (보호자 홈 미설계)

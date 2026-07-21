# client/ — 이룸(ELUM) Flutter 앱

> 보호자 모드 + 아동 모드를 한 앱에서 전환하는 Flutter 앱.
> 서비스 배경·기획은 저장소 루트 [`docs/`](../docs/README.md)를 먼저 읽을 것.

## 이 문서의 역할

`client/` 안에서 코드를 쓸 때 지켜야 할 **규칙과 구조**를 정의한다.
화면별 상세 명세는 아래 문서로 분리되어 있다.

| 문서 | 내용 |
| --- | --- |
| [docs/design-system.md](./docs/design-system.md) | 색·타이포·간격·컴포넌트 토큰 (Figma 추출값) |
| [docs/onboarding-flow.md](./docs/onboarding-flow.md) | 온보딩 12개 프레임 화면별 명세 |
| [docs/architecture.md](./docs/architecture.md) | 폴더 구조, 상태관리, 라우팅, 서버 연동 규칙 |

## 기술 스택 (확정)

| 영역 | 선택 | 이유 |
| --- | --- | --- |
| 상태관리 | **Riverpod** (`flutter_riverpod`) | 서버 미완성 구간을 mock provider로 갈아끼우기 쉬움 |
| 라우팅 | **go_router** | 온보딩 단계별 딥링크·뒤로가기 제어가 명확 |
| 모델 | **Freezed** | 불변 모델 + `copyWith` |
| HTTP | **dio** | 인터셉터로 실패 시 fallback 체인 처리 |
| 로컬 저장 | **shared_preferences** | 온보딩 결과(호칭·목표·캐릭터·PIN) 저장 |
| TTS | **flutter_tts** (예정) | 아동 모드 음성 안내 |

> **의존성 제약 (실제로 부딪힌 것)**
> - `riverpod_generator` — `flutter_riverpod 3.3.2`와 analyzer 버전이 충돌한다. provider를 손으로 선언한다.
> - `json_serializable` — 같은 이유로 제외. JSON 파싱은 모델에 직접 쓴다 (필드가 적어 충분하다).
> - `flutter_secure_storage` — 의존하는 `objective_c`의 build hook이 Dart 3.10에서 `build_runner`의
>   AOT 컴파일을 깨뜨린다. 현재 PIN은 `shared_preferences`에 저장하며, `LocalStorage`가
>   메서드로 감싸두어 나중에 교체해도 호출부는 그대로다.

> 해커톤 24시간 기준. 새 패키지를 추가할 땐 **데모 성립 조건**([../docs/07-mvp-scope.md](../docs/07-mvp-scope.md))에 필요한지 먼저 따진다.

## 코딩 규칙

### 필수

- **주석은 한국어**, WHY 중심으로 간결하게. 코드만 봐도 아는 내용은 쓰지 않는다.
- **디자인 토큰 하드코딩 금지.** 색·폰트·간격은 반드시 `core/theme/`의 `AppColors` / `AppTypography` / `AppSpacing`을 통해 쓴다.
  ```dart
  // ❌ Color(0xFF443E39), fontSize: 28
  // ✅ AppColors.textPrimary, AppTypography.title
  ```
- **화면 위젯은 `ConsumerWidget` 우선.** `StatefulWidget`은 애니메이션 컨트롤러가 필요할 때만.
- **`build()` 안에서 비즈니스 로직 금지.** provider 또는 notifier로 뺀다.
- 한 파일 300줄을 넘기면 위젯을 분리한다.

### 아동 모드 전용 규칙

아동 모드는 발달장애 아동이 직접 조작한다. 아래는 접근성 요구사항이자 서비스 정체성이다.

- 터치 타겟 **최소 64×64** (일반 44보다 크게)
- 한 화면에 **행동 하나**, 선택지 2개 이하
- 애니메이션은 **300ms 이상** — 급격한 전환은 쓰지 않는다
- 텍스트 최소 20sp, 실패/에러 표현에 빨강·경고 아이콘 사용 금지

### 서버 연동 규칙 (중요)

**API를 붙일 땐 반드시 `server/`의 실제 코드를 읽고 맞춘다.**
`docs/06-api-spec.md`는 초안이라 실제 구현과 다를 수 있다. **서버 코드가 기준이다.**

| 확인할 것 | 위치 |
| --- | --- |
| 엔드포인트 | `server/src/main/java/**/application/controller/*Controller.java` |
| 요청·응답 필드 | 같은 패키지의 `dto/` |
| enum 값 | `server/src/main/java/**/infrastructure/entity/*.java` |

이미 맞춰둔 계약:

- `SupportGoal` → `member/infrastructure/entity/SupportGoal.java`
  (`STEP_BY_STEP` / `PREPARE_ITEMS` / `PREPARE_NEW` / `INDEPENDENT`)
- `ActionCard` → `routine/infrastructure/entity/RoutineStep.java`
  (`id` / `description` / `stepOrder` / `imagePath` / `completed`)

주요 엔드포인트: `/api/auth`, `/api/member`, `/api/routines`

> 서버 enum이나 필드명이 바뀌면 **클라이언트 도메인 모델을 먼저 맞추고** 테스트를 돌린다.
> `test/onboarding_profile_test.dart`에 서버 계약 검증 테스트가 있다.

### 금지

- `print()` — `debugPrint()` 사용
- 보호자 입력 원문을 로그에 남기는 것 (루트 docs 원칙 5번)
- 아동 화면에 **미승인 카드** 렌더링 (원칙 3번)
- **추측으로 API 필드명 짓기** — 서버 코드를 열어보고 쓴다
- **URL·타임아웃 등 환경값 하드코딩** — `AppConfig` 경유
- **에셋 경로 문자열 직접 쓰기** — `AppAssets` 경유

---

## 🔧 관리 포인트 (여기부터가 유지보수의 핵심)

무엇을 고칠 때 **어디를 함께 고쳐야 하는지**를 정리한다.
한 곳만 고치면 조용히 어긋나는 것들이라, 작업 전에 이 표를 먼저 본다.

### 1. 환경변수를 추가할 때

값이 환경(로컬/운영)에 따라 달라지거나 나중에 조정될 여지가 있으면 **코드에 박지 말고 `.env`로 뺀다.**

| 순서 | 할 일 |
| --- | --- |
| 1 | `.env.example`에 키 + 설명 주석 추가 (**커밋함** — 어떤 키가 필요한지의 유일한 문서) |
| 2 | `lib/core/config/app_config.dart`에 getter 추가 (**기본값 필수**) |
| 3 | 로컬 `.env`에도 추가 (**커밋 안 함**) |
| 4 | 배포용이면 GitHub Secret `CLIENT_ENV_FILE` 갱신 |

```dart
// AppConfig에 추가할 때 — 값이 없거나 형식이 틀려도 앱은 떠야 한다
static int get retryCount => _int('ELUM_RETRY_COUNT', 3);
```

> **기본값 없는 환경변수를 만들지 않는다.** `.env`를 안 만든 신규 개발자의 앱이 죽으면
> 원인을 찾는 데 시간이 갈린다. `AppConfig.load()`는 `.env`가 없어도 경고만 남기고 진행한다.

**민감값 판단 기준**: 서버 주소·타임아웃 같은 건 `.env`로 충분하다.
API 키·인증서처럼 **유출되면 안 되는 값**은 반드시 GitHub Secret으로만 관리하고
`.env.example`에는 빈 값으로 둔다.

### 2. 에셋을 추가할 때

| 순서 | 할 일 |
| --- | --- |
| 1 | `assets/images/`에 파일 배치 (Figma에서 SVG로 추출) |
| 2 | `lib/core/assets/app_assets.dart`에 상수/함수 추가 |
| 3 | `pubspec.yaml`의 `assets:`는 디렉토리 단위라 **보통 수정 불필요** |

> 위젯에 `'assets/images/foo.svg'`를 직접 쓰지 않는다. 오타는 런타임에야 드러난다.
> enum과 1:1 대응하는 에셋은 `switch`로 매핑해 **새 enum 값 추가 시 컴파일 에러**로 잡히게 한다.

### 3. 디자인 토큰을 바꿀 때

**Figma가 바뀌면 코드보다 `docs/design-system.md`를 먼저 고친다.**

| 순서 | 할 일 |
| --- | --- |
| 1 | Figma **컴포넌트셋 원본**에서 값 확인 (인스턴스는 특정 variant만 보여준다) |
| 2 | `docs/design-system.md` 표 갱신 |
| 3 | `lib/core/theme/app_colors.dart` 등 토큰 수정 |

> ⚠️ 실제로 겪은 실수: 온보딩 프레임의 버튼 인스턴스가 전부 `disable`로 찍혀 있어
> enable 색이 없는 줄 알았다. 컴포넌트셋(`187:299`)에는 두 variant가 다 있었다.
> **인스턴스가 아니라 컴포넌트셋이 원본이다.**

### 4. 서버 API가 바뀔 때

| 순서 | 할 일 |
| --- | --- |
| 1 | `server/`의 Controller·Entity·DTO를 **직접 읽는다** |
| 2 | 클라이언트 도메인 모델(enum `apiValue`, 모델 필드명) 수정 |
| 3 | `flutter test` — 서버 계약 검증 테스트가 잡아준다 |

> ⚠️ 실제로 겪은 실수: `docs/06-api-spec.md` 초안대로 `SupportGoal`을 만들었는데
> 서버 실제 enum과 값이 전부 달랐다. **문서가 아니라 서버 코드가 기준이다.**

### 5. 화면을 추가할 때

| 순서 | 할 일 |
| --- | --- |
| 1 | `Routes`에 경로 상수 추가 (문자열 직접 쓰지 않음) |
| 2 | `createRouter()`에 `GoRoute` 등록 |
| 3 | `features/<기능>/presentation/`에 화면 작성 |
| 4 | 화면 전용 위젯은 그 아래 `widgets/`에 |

**공통 위젯 승격 기준**: 두 번째 화면이 같은 위젯을 필요로 할 때 `core/widgets/`로 옮긴다.
화면 하나만 보고 미리 공통화하면 파라미터가 계속 붙어 결국 아무도 못 고치는 위젯이 된다.

### 6. 코드 생성이 필요할 때

Freezed 모델(`@freezed`)을 수정하면 **반드시** 재생성한다. 안 하면 "파라미터가 없다"는
엉뚱한 컴파일 에러가 난다.

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 알아둘 함정 (실제로 부딪힌 것들)

| 증상 | 원인 | 대응 |
| --- | --- | --- |
| `Failed to compile build script` | build hook이 있는 패키지(`objective_c` 등)가 `build_runner` AOT를 깨뜨림 | 해당 패키지 제외 또는 대체 |
| "No named parameter" 인데 코드는 맞음 | Freezed 생성 파일이 낡음 | `build_runner build` 재실행 |
| `riverpod_generator`/`json_serializable` 추가 실패 | `flutter_riverpod 3.3.2`의 analyzer 제약과 충돌 | provider 수동 선언, JSON 직접 파싱 |
| 폰트가 안 나옴 | `pubspec.yaml` fonts 선언 누락 | `flutter build bundle` 후 `FontManifest.json` 확인 |

## 폰트

`assets/fonts/`에 설치 완료. `pubspec.yaml`에 선언되어 있다.

| Figma 이름 | 파일 | weight |
| --- | --- | --- |
| Tmoney RoundWind (800) | `TmoneyRoundWindExtraBold.ttf` | `w800` |
| Tmoney RoundWind (400) | `TmoneyRoundWindRegular.ttf` | `w400` |

> `Cloudsofa_namgim`(로고 64px)은 **아직 미확보**. 로고는 당분간 SVG/이미지 에셋으로 처리하고,
> 폰트로 렌더링하지 않는다. → [docs/design-system.md](./docs/design-system.md#미확보-폰트)

## 자주 쓰는 명령

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Freezed/Riverpod 코드 생성
flutter analyze
flutter run
```

> Freezed 모델이나 `@riverpod` provider를 수정하면 **반드시 build_runner를 다시 돌린다.**

## 미확정 사항

- 서버 base URL (로컬 LLM 연결 정보 확정 전까지 mock repository 사용)
- 아동 모드 → 보호자 모드 전환 시 PIN 검증 로직 (온보딩에서 PIN 저장까지만 구현)
- 캐릭터 에셋(여우/고양이 외 추가분) 확보 여부

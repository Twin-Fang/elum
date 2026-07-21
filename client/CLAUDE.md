# client/ — 이룸(ELUM) Flutter 앱

> 보호자 모드 + 아동 모드를 한 앱에서 전환하는 Flutter 앱.
> 서비스 배경·기획은 저장소 루트 [`docs/`](../docs/README.md)를 먼저 읽을 것.

## 이 문서의 역할

`client/` 안에서 코드를 쓸 때 지켜야 할 **규칙과 구조**를 정의한다.
화면별 상세 명세는 아래 문서로 분리되어 있다.

| 문서 | 내용 |
| --- | --- |
| [docs/design-system.md](./docs/design-system.md) | 색·타이포·간격·컴포넌트 토큰 (Figma 추출값) |
| [docs/motion.md](./docs/motion.md) | **애니메이션 duration·curve·눌림 반응** — 화면에 모션을 넣기 전 |
| [docs/onboarding-flow.md](./docs/onboarding-flow.md) | 온보딩 12개 프레임 화면별 명세 + **프레임 노드 ID 표** |
| [docs/architecture.md](./docs/architecture.md) | 폴더 구조, 상태관리, 라우팅, 서버 연동 규칙 |
| [docs/troubleshooting.md](./docs/troubleshooting.md) | **실제로 겪은 문제와 해결법** — 에러를 만나면 여기부터 |

## 원본이 어디 있는가 ⚠️ 먼저 읽을 것

추측해서 만들지 않는다. 화면도 API도 **원본을 열어보고** 맞춘다.

### Figma — 디자인 원본

```
파일     https://www.figma.com/design/VSmGuv1iuOpLZmp6QeBHWr/이룸
fileKey  VSmGuv1iuOpLZmp6QeBHWr
최상위    238:1846  "이게 진짜 디자인"  ← 여기서부터 훑는다
```

최상위 아래 구조 (2026-07-21 덤프 기준):

| 노드 | 이름 | 타입 | 내용 |
|---|---|---|---|
| `238:3022` | 온보딩 | SECTION | 프레임 12개 — 이름·목표·캐릭터·비밀번호·시작 |
| `309:2836` | 보호자 | SECTION | 프레임 21개 — 홈·일과 만들기·맞춤설정완료 |
| `309:3172` | 아이_홈 | FRAME | 아이용 홈 화면 |
| `309:2837` | 보호자_아이화면_전환 | FRAME | 암호 입력 후 아이 화면 전환 |

화면별 프레임 노드 ID는 [docs/onboarding-flow.md](./docs/onboarding-flow.md#프레임--노드-id)에 있다.

> ⚠️ **디자이너가 Figma를 계속 수정 중이다.** 문서에 적힌 좌표·색은 **덤프한 시점의 값**이다.
> 화면을 건드리기 전에 **매번 다시 덤프한다.** 문서를 믿고 그대로 쓰지 않는다.
> 노드 ID도 프레임이 재생성되면 바뀔 수 있으므로, 못 찾으면 최상위(`238:1846`)부터 다시 훑는다.

**규칙**

1. Figma URL(`?node-id=204-1002`)을 받으면 `mcp__figma__get_figma_data`로 **그 노드를 직접 덤프**한다.
2. 덤프와 `docs/`의 명세가 다르면 **덤프가 기준**이다. 문서를 고친다.
3. 덤프에 없는 색·간격을 추측해 채우지 않는다. 모르면 **사용자에게 묻는다.**
4. 에셋(`IMAGE-SVG`/`COMPONENT`/`INSTANCE`)은 코드보다 **먼저** 다운로드한다 (§2 에셋 우선 원칙).
5. 문서를 고칠 땐 **덤프한 날짜를 남긴다.** 언제 기준 값인지 모르면 다음 사람이 판단할 수 없다.

> URL의 `node-id=204-1002`는 MCP 호출 시 `204:1002`로 바꿔 쓴다(하이픈→콜론).

### 서버 — API 원본

```
Swagger  https://api.elum.chuseok22.com/v3/api-docs      ← 배포된 계약(OpenAPI JSON)
내부 로직  <repo>/server/src/main/java/com/chuseok22/elumserver/**
```

**Swagger는 "무엇을 받는가", `server/` 코드는 "왜 그런가"를 본다.**
필드명·enum 값이 궁금하면 Swagger로 충분하다. 검증 규칙·분기·실패 동작을 알아야 하면
`server/`의 Controller·DTO·Entity를 직접 연다. 둘이 다르면 **서버 코드가 기준이다.**

온보딩이 쓰는 엔드포인트:

| 메서드 | 경로 | 용도 |
| --- | --- | --- |
| PATCH | `/api/member/nickname` | 호칭 저장 |
| PATCH | `/api/member/support-goals` | 도움 목표 저장 |
| GET | `/api/member/me` | 프로필 조회 |

## 기술 스택 (확정)

| 영역 | 선택 | 이유 |
| --- | --- | --- |
| 상태관리 | **Riverpod** (`flutter_riverpod`) | 서버 미완성 구간을 mock provider로 갈아끼우기 쉬움 |
| 라우팅 | **go_router** | 온보딩 단계별 딥링크·뒤로가기 제어가 명확 |
| 모델 | **Freezed** | 불변 모델 + `copyWith` |
| HTTP | **dio** | 인터셉터로 실패 시 fallback 체인 처리 |
| 로컬 저장 | **shared_preferences** | 온보딩 결과(호칭·목표·캐릭터·PIN) 저장 |
| TTS | **flutter_tts** (예정) | 아동 모드 음성 안내 |

> **제외한 패키지**: `riverpod_generator`, `json_serializable`(analyzer 충돌),
> `flutter_secure_storage`(build hook이 build_runner를 깨뜨림).
> 이유와 대응은 [트러블슈팅](./docs/troubleshooting.md#build_runner-aot-컴파일-실패) 참조.
>
> ⚠️ PIN이 현재 **평문 저장**된다. 발표 전 재검토 대상.

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
- `ActionCard` → `routine/.../RoutineStepResponse.java`
  (`id` / `stepOrder` / `description` / `imagePath` / `completed` / `completedAt`)

#### `/api/routines` 계약 요약

| 메서드 | 경로 | 용도 |
| --- | --- | --- |
| POST | `/api/routines/questions` | AI 추가 질문 생성 (**실패해도 항상 200**) |
| POST | `/api/routines` | 일과 생성 → 카드 생성 |
| GET | `/api/routines/{id}` | 단건 조회 |
| PATCH | `/api/routines/{id}/revise` | 피드백으로 재생성 |
| PATCH | `/api/routines/{id}/confirm` | **보호자 승인** (이후 아동에게 노출) |
| PATCH | `/api/routines/{id}/steps/{stepId}` | 단계 문장 수정 |
| PATCH | `.../steps/{stepId}/complete` \| `/cancel` | 아동 수행 체크 |

**`RoutineResponse`의 DLP 관련 필드 — 발표 핵심**

- `rawInputText` — 마스킹 **전** 원문
- `sanitizedInputText` — 마스킹 **후** (실제 LLM에 전달된 값)

이 두 필드로 "전송 전/후 비교" 화면을 만든다. 서버가 이미 검증용으로 노출해주고 있으므로
클라이언트에서 마스킹을 흉내내지 않는다.

> ⚠️ `rawInputText`는 **원문이므로 로그에 남기지 않는다.** 서버도 `@LogMonitoring(logResult=false)`로
> 막아뒀다. 클라이언트 로깅 인터셉터도 body를 찍지 않는다.

> 서버 enum이나 필드명이 바뀌면 **클라이언트 도메인 모델을 먼저 맞추고** 테스트를 돌린다.
> `test/onboarding_profile_test.dart`에 서버 계약 검증 테스트가 있다.

### 브랜치 전략 (필수)

**구현은 `develop`에서 한다. `main`에 직접 커밋하지 않는다.**

```
develop  ← 작업을 모으는 브랜치 (여기서 구현)
  ↓ 릴리스 PR
main     ← 배포 트리거 (버전·릴리스 노트 자동 관리)
```

작업 순서: **설계 → 이슈 생성 → (워크트리 생성) → 구현 → 커밋**

- 이슈 생성: `/pro-github`
- 워크트리: `/pro-init-worktree` — 브랜치명 `YYYYMMDD_#이슈번호_제목`
- 배포: `/pro-changelog-deploy` (main push만으로는 배포되지 않는다)

> 시간이 급하면 워크트리 없이 `develop`에서 직접 작업해도 된다.
> 다만 **`main` 직접 커밋은 하지 않는다** — 배포가 자동 트리거된다.

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

### 2. Figma 화면을 구현할 때 — 에셋 우선 원칙 ⚠️ 최우선

> **원본이 있으면 절대 추측하지 않는다. 이 문서에서 가장 중요한 규칙이다.**

지금까지 발생한 사고 3건(버튼 색 추측 / enum 불일치 / 일러스트가 사각형)의 원인이
**전부 동일**하다 — 원본이 있는데 추측했다. → [사고 기록](./docs/troubleshooting.md)

**화면 구현 순서 (건너뛰지 말 것)**

| 순서 | 할 일 |
| --- | --- |
| 1 | `mcp__figma__get_figma_data`로 **해당 노드 덤프 조회** |
| 2 | 덤프에서 `type: IMAGE-SVG`, `type: COMPONENT`, `type: INSTANCE`를 **전부 목록화** |
| 3 | 그것들을 `mcp__figma__download_figma_images`로 **먼저 다운로드** |
| 4 | `AppAssets`에 상수 추가 |
| 5 | **그 다음에야** 코드를 쓴다 |

**절대 금지**

- ❌ 도형(원·곡선·캐릭터·일러스트)을 `Container`/`CustomPaint`/`BoxDecoration`으로 그리기
- ❌ 그라데이션이 들어간 요소를 코드로 재현하기
- ❌ "대충 비슷하게" 만들고 나중에 맞추기

```dart
// ❌ 이렇게 하다 병아리가 사각형이 됐다
Container(decoration: BoxDecoration(gradient: RadialGradient(...)))

// ✅ SVG 안에 둥근 path와 그라데이션이 이미 들어있다
SvgPicture.asset(AppAssets.splashChickBody, width: 393.w)
```

**코드로 그려도 되는 것**: 단색 배경, 직사각형 카드, 테두리, 단순 선형 그라데이션(배경 정도).
그 외 형태가 있는 것은 **전부 에셋**이다.

**좌표·크기는 ScreenUtil로**

Figma 좌표(393×852 기준)를 그대로 쓰되 `.w`/`.h`/`.sp`를 붙인다.
비율을 손으로 계산하지 않는다.

```dart
Positioned(left: 115.w, top: 214.h, child: SvgPicture.asset(AppAssets.logo, width: 164.w))
```

#### 에셋 파일 추가 절차

| 순서 | 할 일 |
| --- | --- |
| 1 | `assets/images/`에 파일 배치 (Figma에서 SVG 추출) |
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

> **인스턴스가 아니라 컴포넌트셋이 원본이다.** 인스턴스는 특정 variant 하나만 보여준다.
> → [버튼 색을 잘못 읽은 사고](./docs/troubleshooting.md#버튼-enable-색을-잘못-읽음)

#### 토큰 파일은 하나다

**모든 색은 `lib/core/theme/app_colors.dart`, 모든 폰트는 `app_typography.dart`.**
화면이 늘어나도 파일을 나누지 않는다. 찾을 곳이 하나여야 한다.

#### 같은 색이어도 쓰임이 다르면 토큰을 나눈다 ⚠️

HEX가 같다고 합치지 않는다. 합치면 **한쪽만 바꿔야 할 때 못 바꾼다.**

```dart
catSelectedBorder: Color(0xFF9CADF1),  // 캐릭터 선택 테두리
homeCardTitle:     Color(0xFF9CADF1),  // 홈 카드 제목 ← 값이 같아도 따로
```

판단 기준은 **"이 둘은 항상 같이 바뀌어야 하는가?"** 아니라면 나눈다.
중복 상수 몇 줄보다, 색이 엉뚱한 화면까지 번지는 비용이 크다.
(실제로 셋을 묶었다가 목표 칩에 여우색이 들어간 적이 있다 — 이슈 #11)

#### 새 크기가 나오면 토큰을 추가한다 — `copyWith(fontSize:)` 금지

```dart
// ❌ Figma가 17→18로 바뀔 때 grep으로 못 찾는다
context.typo.subtitle.copyWith(fontSize: 17, color: ...)
// ✅
context.typo.cardTitle.copyWith(color: ...)
```

`copyWith`로 **색만** 주는 건 정상이다.

#### `AppColors`에 필드를 추가하면 5곳을 고친다

선언 / 생성자 / `light` / `copyWith` / `lerp`.
앞 3개는 컴파일러가 잡지만 **`copyWith`·`lerp` 누락은 안 잡힌다.**
`lerp`를 빠뜨리면 테마 전환 애니메이션에서만 드러난다.

상세와 전체 토큰표는 [docs/design-system.md](./docs/design-system.md#색상-appcolors).

### 4. 서버 API가 바뀔 때

| 순서 | 할 일 |
| --- | --- |
| 1 | `server/`의 Controller·Entity·DTO를 **직접 읽는다** |
| 2 | 클라이언트 도메인 모델(enum `apiValue`, 모델 필드명) 수정 |
| 3 | `flutter test` — 서버 계약 검증 테스트가 잡아준다 |

> **문서가 아니라 서버 코드가 기준이다.**
> → [enum 불일치 사고](./docs/troubleshooting.md#supportgoal-enum-값이-서버와-전부-달랐음)

### 5. 화면을 추가할 때

| 순서 | 할 일 |
| --- | --- |
| 1 | `Routes`에 경로 상수 추가 (문자열 직접 쓰지 않음) |
| 2 | `createRouter()`에 `GoRoute` 등록 |
| 3 | **위젯 테스트를 먼저 쓴다** (§6 참조) |
| 4 | `features/<기능>/presentation/`에 화면 작성 |
| 5 | 화면 전용 위젯은 그 아래 `widgets/`에 |

**공통 위젯 승격 기준**: 두 번째 화면이 같은 위젯을 필요로 할 때 `core/widgets/`로 옮긴다.
화면 하나만 보고 미리 공통화하면 파라미터가 계속 붙어 결국 아무도 못 고치는 위젯이 된다.

### 6. 테스트 — 구현 전에 쓴다 (TDD)

**AI가 Flutter 코드를 쓸 때 가장 자주 내는 실수는 테스트로 잡힌다.**
지금까지 낸 버그 중 계약 불일치·조사 누락·예약어 충돌은 전부 테스트가 있었으면 즉시 드러났다.

#### 3단계 테스트

| 층 | 대상 | 도구 | 언제 |
| --- | --- | --- | --- |
| **단위** | 도메인 모델, repository, DLP 로직 | `flutter test` | 로직이 있으면 항상 |
| **위젯** | 화면 구성·CTA 활성 조건·네비게이션 | `testWidgets` | 화면을 만들 때 |
| **골든** | 렌더링 결과 이미지 회귀 | `matchesGoldenFile` | 화면이 승인된 뒤 |

#### 순서

```
1. 테스트를 먼저 쓴다 (실패하는 것을 확인)
2. 구현한다
3. 통과시킨다
4. (화면이면) 사용자가 눈으로 승인 → 골든 이미지 생성
```

#### 반드시 테스트로 고정할 것

- **서버 계약** — enum `apiValue`, 모델 필드명. 어긋나면 조용히 실패한다
- **fallback** — "어떤 실패에도 카드가 나온다"는 데모 성립 조건이다
- **원문 비저장** — 탐지 결과에 원문이 섞이지 않는지 (docs 원칙 5번)
- **에셋 사용** — 도형을 코드로 그리지 않았는지
  (예: `test/splash_screen_test.dart`의 "병아리 몸통을 SVG로 렌더링한다")

#### 위젯 테스트 작성법

저장소는 인터페이스이므로 `InMemoryStorage`로 바꿔 끼운다.
`SharedPreferences`는 플랫폼 채널을 타서 위젯 테스트에서 쓸 수 없다.

```dart
ProviderScope(
  overrides: [testStorageOverride(onboardingCompleted: false)],
  child: ScreenUtilInit(designSize: const Size(393, 852), builder: ...),
)
```

`ScreenUtilInit`으로 감싸지 않으면 `.w`/`.h`가 터진다. 헬퍼는 `test/helpers/`에 둔다.

#### 골든 테스트 주의

**골든은 "Figma와 같은가"를 판단해주지 못한다.** 첫 이미지가 틀리면 틀린 것을 고정한다.
그래서 **첫 승인은 반드시 사람이 눈으로** 한다. 이후에는 회귀 방지용으로 동작한다.

```bash
flutter test --update-goldens   # 의도한 변경일 때만
```

### 7. 코드 생성이 필요할 때

Freezed 모델(`@freezed`)을 수정하면 **반드시** 재생성한다. 안 하면 "파라미터가 없다"는
엉뚱한 컴파일 에러가 난다.

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 알아둘 함정 — 증상별 빠른 조회

증상이 익숙하면 아래에서 찾고, 상세는 [트러블슈팅 문서](./docs/troubleshooting.md)를 본다.

| 증상 | 한 줄 대응 |
| --- | --- |
| 일러스트가 네모나게 나옴 | 도형을 코드로 그렸다 → SVG 다운로드 (§2) |
| `Failed to compile build script` | build hook 가진 패키지가 원인 → 제외/대체 |
| "No named parameter" 인데 코드는 맞음 | Freezed 생성 파일이 낡음 → `build_runner build` |
| 코드 생성 패키지 추가 실패 | analyzer 버전 충돌 → `--dry-run`으로 먼저 확인 |
| 폰트가 안 나옴 | `pubspec.yaml` 선언 누락 → `FontManifest.json` 확인 |
| 텍스트인 줄 알았는데 폰트가 없음 | 실은 이미지일 수 있다 → Figma 노드 타입 확인 |
| 위젯 테스트에서 `.w` 에러 | `ScreenUtilInit` 누락 |
| 화면 문구에 조사만 남음 | 사용자 입력이 빈 값 → 대체어 getter |

> **새 문제를 해결했으면 [트러블슈팅 문서](./docs/troubleshooting.md)에 기록한다.**
> 템플릿이 있고, **재발 방지 칸(규칙/테스트)을 반드시 채운다.**
> 기록만 하고 끝나면 같은 문제가 또 난다.

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

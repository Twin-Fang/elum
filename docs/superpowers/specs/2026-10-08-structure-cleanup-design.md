# 구조 정리 (의존 방향 · 공통화 · 분할 · 주석) 설계

## 배경

2026-10-08에 클라이언트와 서버 전체를 점검했다. 작업 범위는 아래 목록과 같다.

- 의존 방향이 거꾸로 된 곳: 클라는 core에서 features로 59줄, 서버는 common에서 도메인으로 7개 파일
- 1,000줄 안팎의 큰 파일
- 반복되는 위젯과 try/catch 틀
- 쓰이지 않는 파일 483줄
- 이슈 번호나 과거 경위가 든 주석 1,381줄 이상
- dev와 prod가 같은 JWT 서명 키를 쓰는 문제

## 대전제: 운영 중인 앱이다

이룸은 앱스토어에 올라가 있고 실제 사용자가 쓰고 있다. develop은 나중에 main으로 배포된다.
따라서 **모든 작업은 동작을 보존하는 리팩터링**으로 한다.

| 바꾸지 않는 것 | 확인 방법 |
|---|---|
| API 경로·요청/응답 JSON 모양·HTTP 상태 | 기존 컨트롤러 테스트 통과, DTO 필드명 diff 확인 |
| 에러 코드(`E-xxxx`)와 문구 키 | `ErrorMessagesStartupGuard`, 문구 패리티 테스트 |
| DB 스키마 | Flyway 마이그레이션을 추가하지 않는다 |
| 클라 저장소 키(SharedPreferences·secure storage) | 키 문자열 상수를 옮기기만 하고 값은 그대로 둔다. diff로 확인 |
| 트랜잭션 전파 | 클래스 분할 뒤에도 `@Transactional` 전파 속성이 같고, 자기 호출로 프록시가 빠지는 곳이 없다 |
| 운영 AI 동작(제공자 선택·폴백·재시도·타임아웃 값) | 값을 옮기기만 하고 바꾸지 않는다 |

**하지 않는 것**

- 운영 JWT 키 교체: 모든 사용자가 로그아웃되므로 하지 않는다.
- 운영 Secret 수정과 배포
- 텍스트 AI 폴백 체인과 재시도 도입: 운영 동작이 바뀌므로 별도 이슈로만 남긴다.

## 이슈 구성과 순서

다른 세션과 겹치지 않는 것부터 진행한다.
`#560` 세션이 `app_router`·`local_storage`·`dev_tools_overlay`·`login_screen`·`auth_repository`·`token_store`를
수정하고 있으므로, 이 파일들을 건드리는 8·9번은 `#560`이 develop에 머지된 뒤에 착수한다.

### 1. dev 와 운영의 JWT 서명 키 분리 (내부 처리, 이슈 없음)

로컬 `application-dev.yml` 키를 80자 무작위 값으로 바꿨다(2026-10-08). git 미추적 파일이라 커밋·이슈가 없다. 운영 키는 그대로다.

### 2. 🚀[기능개선][클라][공통] 쓰이지 않는 파일 정리

- 삭제 대상
  - `core/widgets/glowing_svg.dart`
  - `core/widgets/secured_by_dlp_badge.dart`
  - `features/guardian/presentation/dlp_screen.dart`
  - `features/auth/presentation/widgets/consent_chip.dart`
  - 추적되지 않는 `lib/_probe_ad_main.dart`
- 이 파일 이름을 가리키는 주석 2곳도 함께 고친다.
- 검증: `flutter analyze`

### 3. 🚀[기능개선][서버][공통] common이 도메인을 거꾸로 의존한다

역의존 제거:
- `GlobalExceptionHandler`가 admin 컨트롤러를 import하지 않게 한다. 마커 애노테이션으로 대상을 지정한다.
- `LinkRole`을 JWT 처리에서 쓰는 위치로 옮기거나 common으로 옮긴다.
- `EnabledLocales`·`MaintenanceModeFilter`·`AppStatusController`·`SecurityConfig`가 `SystemConfigService`를 직접 쓰지 않게 한다. common에 조회용 포트 인터페이스를 두고 systemconfig가 이를 구현한다.

다른 도메인 repository 직접 import:
- 각 도메인이 이미 가진 Query·Service를 통해 접근하도록 바꾼다.
- 한 번에 다 바꾸지 않는다. 트랜잭션 경계가 바뀌지 않는 조회 경로부터 바꾼다.
- 쓰기 경로는 기존 트랜잭션 안에서 호출되는지 확인한 뒤에만 바꾼다.

ArchUnit 테스트:
- 규칙 1: common은 도메인 패키지를 import하지 않는다.
- 규칙 2: 다른 도메인의 `infrastructure.repository`를 import하지 않는다.
- 아직 남은 위반은 동결(freeze) 목록으로 두어 새로 생기는 위반만 막는다.

검증: `./gradlew test`

### 4. 🚀[기능개선][서버][AI] 제공자 HTTP 클라이언트 공통화와 타임아웃 설정화

- OpenAI 텍스트·OpenAI 이미지·Flux 클라이언트에 복사된 `RestClient` 생성 코드를 `AiRestClientFactory` 하나로 모은다.
- 하드코딩된 타임아웃(10초·120초)을 properties로 옮기되 **기본값은 지금 값 그대로** 둔다.
- 폴백과 재시도는 바꾸지 않는다.
- 검증: `./gradlew test` (AI 실제 호출은 하지 않는다)

### 5. 🚀[기능개선][서버][일과] RoutineService 분할

- `RoutineService`(1006줄)를 아래로 나눈다.
  - `RoutineCreateService`: 생성·질문·멱등·크레딧
  - `RoutineQueryService`: 조회
  - `RoutineProgressService`: 진행 상태
  - 사진 처리
- 컨트롤러는 나뉜 서비스를 호출한다. API는 그대로 둔다.
- 메서드별 `@Transactional`(`readOnly`·`NOT_SUPPORTED` 포함)을 그대로 옮긴다.
- 분할하면서 생기는 클래스 간 호출이 기존의 자기 호출과 같은 트랜잭션 의미를 갖는지 확인한다.
- 검증: `./gradlew test`, 루틴 관련 테스트 전부

### 6. 🚀[기능개선][클라][공통] 바텀시트·연결 암호·로딩 공통 위젯

- `core/widgets/elum_bottom_sheet.dart`
  - `showElumSheet`와 `ElumSheetSurface`(배경·둥근 모서리·손잡이)를 둔다.
  - 시트 4곳에 적용한다.
- `link/presentation/widgets/issued_code_panel.dart`: 연결 암호 발급 화면 2곳(`link_code`, `invite_code`)에 적용한다.
- `link/presentation/widgets/code_entry_field.dart`: 암호 입력 화면 2곳(`link_enter`, `invite_enter`)의 입력 위젯만 공통화한다. 화면 로직은 합치지 않는다.
- `core/widgets/elum_spinner.dart`
  - 작은 스피너는 `ElumSpinner`로 바꾼다.
  - 본문 전체 로딩은 `ElumStateBody.loading()`으로 바꾼다.
- 픽셀 값(간격·반지름·크기)은 지금 값 그대로 둔다. 화면이 달라지면 안 된다.
- 검증
  - `flutter analyze`
  - 해당 화면 위젯 테스트
  - 시트·연결 암호 화면 골든 또는 스크린샷 비교로 화면이 그대로인지 확인한다.

### 7. 🚀[기능개선][클라][공통] 저장소 호출 공통화

- `core/network/guarded_call.dart`를 둔다.
  - `guarded<T>()`: `Attempt`를 반환한다.
  - `logged<T>()`: 예외를 다시 던진다.
  - 두 함수 모두 `AppLogger`로 로그를 남긴다.
- 적용 대상은 member·link·credit·notice 저장소다.
- 각 메서드의 실패 반환 방식은 바꾸지 않는다. `rethrow`, `Attempt`, `null` 중 쓰던 것을 그대로 쓴다.
- `features/*/data`의 `debugPrint`는 `AppLogger`로 바꾼다.
- `auth_repository`와 `routine_repository`는 8·9번 이후로 미룬다.
- 검증: `flutter analyze`, 저장소 단위 테스트

### 8. 🚀[기능개선][클라][구조] core가 features를 거꾸로 의존한다 (`#560` 머지 후)

- `Character`·`SupportGoal`·`RewardCharacter` 같은 공용 도메인 타입을 `shared/domain`으로 옮긴다.
- `localStorageProvider`를 `core/storage`로 옮긴다.
- `memberProvider`와 `MemberRepository`를 `features/member`로 분리한다.
- `dio_client`는 core 인터페이스(토큰·프로필 헤더·인증 실패 처리)만 받는다. 구현은 `main.dart`에서 override한다.
- import 규칙 검사를 `client/tool/`에 추가하고 CI에 건다.
  - core는 features를 import하지 않는다.
  - feature는 다른 feature의 `data/`와 `presentation/`을 import하지 않는다.
  - 남은 위반은 허용 목록으로 동결한다.
- 검증: `flutter analyze`, 전체 `flutter test`

### 9. 🚀[기능개선][클라][구조] 큰 파일 분할과 화면 Controller 계층 (`#560` 머지 후)

파일 분할:
- `routine_repository.dart`: api / repository / providers로 나눈다.
- `routine_notifier.dart`: 입력 / 생성 / 리뷰 Notifier로 나눈다.
- `local_storage.dart`: 구현체를 별도 파일로 꺼내고 기능별 인터페이스로 나눈다. **키 문자열은 그대로 둔다.**
- `app_router.dart`: feature별로 `xxx_routes.dart`를 둔다.
- `dev_tools_overlay.dart`: 화면별로 파일을 나눈다.

화면 Controller:
- 화면이 repository나 storage를 직접 부르는 27곳을 화면별 Controller(Notifier)로 옮긴다.
- 대상: `login`·`consent`·`role_select`·`mode_switch`부터

OAuth 표시 이름:
- `'카카오'` 같은 한글 리터럴을 ARB 문구로 옮긴다. 5개 언어 패리티를 지킨다.

검증: `flutter analyze`, 전체 `flutter test`, 로그인부터 홈까지 iOS 시뮬레이터 E2E 1회

### 10. 🚀[기능개선][클라·서버][주석] 이슈 번호·경위 주석 정리 (마지막)

- 지우거나 고칠 주석
  - 이슈 번호
  - 날짜
  - 과거 경위("예전에는", "합의", "사고였다")
  - 코드를 보면 아는 재진술
  - 9줄이 넘는 설명 문단(3줄 이내로 줄인다)
- **로직의 이유(WHY)는 남긴다.**
- 주석 처리된 코드 1줄은 지운다.
- 주석만 바꾼다. 코드 줄 diff가 0인지 확인한다(공백 제외).
- 다른 세션과 겹치는 범위를 줄이기 위해 모듈별로 커밋을 나눈다.
- 검증: `flutter analyze`, `./gradlew compileJava`, 코드 줄 diff 0 확인

## 공통 진행 방식

- 이슈마다 `/pro-init-worktree`로 worktree를 만든다. 시작 전에 `origin/develop`을 받는다.
- 구조를 옮기기 전에 해당 동작을 지키는 테스트가 있는지 확인한다. 없으면 먼저 쓴다(TDD).
- 이슈마다 그 모듈의 analyze와 관련 테스트를 돌린다. 전체 테스트는 마지막에 1번만 돌린다(병렬 실행 금지).
- 서브에이전트는 sonnet 이하 모델을 쓴다. 테스트를 실행하지 않고 analyze만 한다.
- 이슈마다 아래 순서로 마무리한다.
  1. `/pro-commit`으로 커밋한다.
  2. develop에 rebase한 뒤 푸시한다.
  3. `/pro-report` 보고서를 남긴다.
  4. 라벨을 `작업완료`로 바꾸고 이슈를 닫는다.
- 배포하지 않는다.

## 실패 경로

| 상황 | 대응 |
|---|---|
| 리팩터링 뒤 테스트 실패 | 원인을 고친다. 테스트 기대값을 바꿔서 통과시키지 않는다 |
| 트랜잭션 의미가 같은지 판단이 안 섬 | 그 메서드는 분할에서 빼고 이슈에 남긴다 |
| 다른 세션과 rebase 충돌 | 양쪽 의도를 살려 해소한다. 판단이 안 서면 묻는다 |
| `#560`이 머지되지 않음 | 8·9번은 착수하지 않고 `작업중`으로 둔다 |
| 화면 비교에서 차이 발견 | 공통 위젯 쪽 값을 맞춘다. 맞출 수 없으면 그 화면은 공통화에서 뺀다 |

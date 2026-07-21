# 보호자_홈 화면 구현 및 서버 API 전면 연결

- 작성일: 2026-07-21
- Figma: `보호자_홈` [217:2655](https://www.figma.com/design/VSmGuv1iuOpLZmp6QeBHWr/이룸?node-id=217-2655)
- 대안 시안(미채택): [217:2304](https://www.figma.com/design/VSmGuv1iuOpLZmp6QeBHWr/이룸?node-id=217-2304) · [204:1049](https://www.figma.com/design/VSmGuv1iuOpLZmp6QeBHWr/이룸?node-id=204-1049)
- Swagger: https://api.elum.chuseok22.com/v3/api-docs

## 배경

온보딩 5개 화면이 끝났다. 온보딩이 끝나면 도착하는 곳이 보호자_홈이므로 이 화면이
앱의 기본 화면이다. 현재 `GuardianHomeScreen`은 mock 수준이고 Figma와 무관하다.

동시에 **클라이언트에 인증이 전혀 없어 서버 API가 하나도 붙어 있지 않다.**
`POST /api/routines`는 코드가 있지만 토큰이 없어 401로 실패하고, `catch`가 조용히
삼켜 로컬 fallback으로만 돌고 있었다. 그래서 아무도 눈치채지 못했다.

이 작업은 두 가지를 함께 한다.

1. 보호자_홈을 Figma `217:2655`대로 구현
2. 서버 API 전체 연결 (인증 포함) — 실제로 동작하게 만든다

## 실 서버 검증 결과

설계 전에 `api.elum.chuseok22.com`에 직접 요청해 확인했다. **추측이 아니다.**

| 엔드포인트 | 결과 |
| --- | --- |
| `POST /api/auth/signup` | 201 |
| `POST /api/auth/login` | 200 — `accessToken` / `tokenType: Bearer` / `expiresIn: 3600000` |
| `GET /api/member/me` | 200 |
| `PATCH /api/member/nickname` | 200 |
| `PATCH /api/member/support-goals` | 200 |
| `POST /api/routines/questions` | 200 — AI 실제 동작 |
| `POST /api/routines` | 200 — 카드 9장 생성 |
| `GET /api/routines` | 200 — 생성한 일과가 실제로 조회됨 |

`GET /api/routines`가 동작하므로 **"최근 일과"는 빈 상태 전용이 아니다.** 실제로 채워진다.

### 검증 중 확인한 사실

**클라이언트의 `SupportGoal.apiValue`는 이미 정확하다.**
검증 중 `ROUTINE_HABIT`을 보내 400을 받았으나, 이는 서버에 없는 값을 임의로 만들어
보낸 탓이다. 실제 enum은 `STEP_BY_STEP` / `PREPARE_ITEMS` / `PREPARE_NEW` /
`INDEPENDENT`이고 클라 코드와 일치한다. 수정할 것이 없다.

> 이 사례가 CLAUDE.md의 "추측으로 API 필드명 짓기 금지" 규칙이 필요한 이유다.
> 서버 코드(`member/infrastructure/entity/SupportGoal.java`)를 읽어야 한다.

## 범위 밖 — 별도 이슈로 분리

아래 두 가지는 검증 중 발견했으나 이 작업 범위가 아니다.

| 문제 | 내용 |
| --- | --- |
| `imagePath` 404 | `data/routine-images/.../1.png`을 토큰 유무 양쪽으로 요청해도 404. 서버가 정적 서빙하지 않아 **아동 카드 이미지를 현재 표시할 수 없다** |
| AI 결과 불일치 | `"비 오는 날 등교 준비하기"`를 보냈는데 제목이 `"하늘이의 새로운 미술 학원 갈 준비하기"`로 생성됨. 직전 `support-goals`(`PREPARE_NEW`)에 과하게 이끌린 것으로 보이며 **서버 프롬프트 문제**라 클라에서 고칠 수 없다 |

## 인증 설계

### 아이 이름을 아이디로 쓴다

Figma에 회원가입·로그인 화면이 **없다.** 임의로 만들면 온보딩 흐름이 끊기고 추측
디자인이 된다. 대신 **온보딩에서 이미 받는 아이 이름을 아이디로 쓴다.**

```
username = 아이 이름 (보호자가 온보딩에서 입력)
password = "00000000" (고정)
```

**비밀번호를 고정값으로 두는 이유.** 기기 ID를 비밀번호로 쓰면 폰을 바꿨을 때 같은
이름으로 로그인할 수 없다(실측: 같은 이름 + 다른 비밀번호 → 401). 고정값이면 이름만으로
계정이 결정되므로 기기가 달라도 복귀된다.

해커톤 범위라 이름 충돌은 문제 삼지 않는다. 같은 이름을 쓰면 같은 계정이다.

`0000`은 서버 제약(`@Size(min=8)`)에 걸려 400이다. 실측으로 확인했고 8자인
`00000000`을 쓴다.

### 회원가입과 로그인은 항상 짝이다

이름 하나로 신규·복귀를 모두 처리한다. 409(`DUPLICATE_USERNAME`)가 "이미 있는
이름"의 신호이므로 이것으로 분기한다.

```
이름 입력 → signup 시도
    ├─ 201 → 신규 사용자 → login → 온보딩 계속 (목표 → 캐릭터 → PIN)
    └─ 409 → 기존 이름   → login → 보호자 홈으로 바로 복귀
```

다른 이름을 넣으면 새 계정이 만들어지고 온보딩을 처음부터 한다.

### 토큰이 없으면 시작 화면으로 보낸다

라우터 가드가 토큰 유무를 본다. 토큰이 없으면 어떤 경로로 들어와도 시작 화면으로
되돌린다. 온보딩 완료 여부만 보던 기존 가드로는 "토큰이 날아간 상태"를 잡지 못한다.

### 이름 길이 제약

서버가 `username`을 4~20자로 제한해 `하늘이`(3자)는 400이다. 클라이언트에서 우회하지
않고 그대로 실패 처리하며, 화면에는 안내 문구만 띄운다.

### 토큰 만료는 반드시 발생한다

`expiresIn`이 3600000ms(1시간)다. 데모 중 만료되면 치명적이므로 Dio 인터셉터가
401을 잡아 자동 재발급한다.

**재시도는 1회만 한다.** 무한 루프를 막기 위해 재시도 요청에 플래그를 심는다.

```dart
// 재발급 후 재시도한 요청이 또 401이면 그대로 실패시킨다.
// 여기서 다시 재발급하면 무한 루프가 된다.
if (err.requestOptions.extra[_retriedKey] == true) {
  return handler.next(err);
}
```

### 저장소 확장

`LocalStorage`에 `accessToken`을 추가한다. 자격증명은 아이 이름(이미 저장 중)과
고정 비밀번호에서 나오므로 따로 보관할 값이 없다.

**일과 원문은 여전히 저장하지 않는다** (docs 원칙 5번).

## 화면 설계

### 구조

Figma는 절대좌표 프레임이지만 `Stack` + `Positioned`로 옮기지 않는다. 추천 일과가
가로 스크롤이고 최근 일과는 개수가 변하므로 세로 스크롤 안의 섹션 구성으로 간다.

```
Scaffold (bottomButton 없음)
└ SingleChildScrollView
  ├ 로고(80×30) + 캐릭터 배지(56×56 우상단)   y=70~113
  ├ "안녕하세요,\n{호칭} 보호자님 👋🏻"        24/w800  y=137
  ├ "오늘은 어떤 일과를 준비할까요?"           16/w400  y=207
  ├ NewRoutineCard (344×94)                    y=246
  ├ ✨ "추천 일과"                             14/w800  y=372
  ├ RecommendedRoutineStrip ← 가로 스크롤      y=404
  ├ 🕐 "최근 일과"                             14/w800  y=543
  └ RecentRoutineSection                       y=575
```

**하단 CTA가 사라진다.** 기존 코드의 "일과 만들기" 버튼은 Figma에서 본문의
`새로운 일과 만들기` 카드로 올라왔다. `ElumScaffold`의 `bottomButton`을 쓰지 않는다.

### 추천 일과 — 가로 스와이프

Figma 좌표가 `x=16, 106, 196, 286`(간격 90 = 타일 86 + 여백 4)이고 4번째 타일의
우측 끝이 372로 콘텐츠 영역 368을 넘어간다.

**이 넘침이 스와이프 어포던스다.** 잘린 타일이 보여야 "더 있다"가 전달되므로
의도적으로 살린다.

```dart
SizedBox(
  height: 105,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    // 타일이 화면 가장자리에 닿아야 잘린 느낌이 산다
    padding: const EdgeInsets.symmetric(horizontal: 16),
    ...
  ),
)
```

### 추천 일과 데이터

지금은 하드코딩한다. **나중에 AI가 동적으로 생성할 자리**다.

색과 이모지가 항목에 딸린 데이터이므로 `AppColors` 토큰으로 빼지 않는다. 전역
의미가 없는 색 8개를 토큰에 넣으면 `AppColors`만 비대해진다. 도메인 객체가 자기
색을 들고 있게 하면 나중에 AI가 생성할 때도 같은 자리로 색이 들어온다.

| 일과 | 타일 | 원 | 이모지 |
| --- | --- | --- | --- |
| 비 오는 날 등교 | `#CEDBEF` | `#A0B7DB` | ☔️ |
| 병원 방문 준비 | `#CEEFEB` | `#ADE2DC` | 🏥 |
| 체험학습 준비 | `#F5E9AE` | `#E0D185` | 🍱️ |
| 새로운 장소 방문 | `#FCCAF3` | `#F4B0E7` | 🚗 |

**이모지는 Figma 원본이 `type: TEXT` / `fontFamily: Pretendard`다.** 아이콘
컴포넌트가 아니라 디자이너가 텍스트로 넣은 것이므로 다운로드할 에셋이 없다.
원본대로 텍스트 이모지를 쓴다. OS마다 모양이 달라지는 것(iOS Apple / Android Noto)은
감수한다.

타일을 탭하면 일과 입력 화면으로 이동하며 문구를 미리 채운다. 기존 DLP → 질문 →
카드 플로우를 그대로 재사용하고, 보호자가 문구를 손댈 수 있다.

### 에셋 (Figma 다운로드 완료)

| 파일 | 크기 | 출처 노드 |
| --- | --- | --- |
| `logo_elum_home.svg` | 80×30 | `217:2674` |
| `home_character_badge.svg` | 56×49 | `217:2670` |
| `home_new_routine_illust.svg` | 47×51 | `217:2675` |
| `icon_sparkles.svg` | 15×18 | `217:2688` |
| `icon_clock.svg` | 18×18 | `217:2690` |
| `home_empty_illust.svg` | 39×33 | `217:2695` |

## 데이터 흐름

```
GuardianHomeScreen
├ memberProvider     → GET /api/member/me   (호칭·별 개수)
└ myRoutinesProvider → GET /api/routines    (최근 일과)
```

`RoutineRepository`는 지금도 **절대 throw하지 않는다.** 이 성질을 그대로 지킨다.
화면은 에러 분기를 쓸 일이 없고, 따라서 빠뜨릴 수도 없다.

두 provider 모두 실패 시 로컬 온보딩 값으로 fallback한다. 서버가 죽어도 화면은 뜬다.

## 실패 경로

행복 경로만 구현하지 않는다. 아래를 함께 만든다.

| 상황 | 처리 |
| --- | --- |
| 토큰 만료(401) | 자동 재발급 후 1회 재시도 |
| 재발급도 실패 | 로컬 온보딩 값으로 표시, 에러코드 `E-AUTH` 노출 |
| `GET /routines` 실패 | 빈 목록으로 처리 = Figma 빈 상태 (로딩과 시각적으로 구분) |
| 목록 0건 | `아직 만든 일과가 없어요 😢` + 일러스트 |
| 이름 미설정 | 서버 nickname → 로컬 온보딩 값 → `우리 아이` |
| 로딩 중 | 스켈레톤 표시. 무한 로딩 금지 |
| 네트워크 없음 | 로컬 값으로 화면 구성. 빈 화면 금지 |

에러 코드를 반드시 화면에 노출한다. 사용자에게는 "문제가 발생했습니다"로 충분하지만
`E-AUTH` 같은 식별자가 있어야 제보를 받았을 때 추적할 수 있다.

## 테스트 계획

구현 전에 실패하는 테스트를 먼저 쓴다.

**`test/guardian_home_screen_test.dart`**

- Figma 문구가 보인다 (`추천 일과` / `최근 일과` / `새로운 일과 만들기`)
- 하단 CTA가 없다 — 본문 카드로 올라왔다는 회귀 방지
- 추천 일과 4개가 Figma 순서대로 보인다
- 추천 타일이 가로 스크롤이다 (`scrollDirection: Axis.horizontal`)
- 추천 타일 탭 → 입력 화면으로 이동하며 문구가 채워진다
- 일과 0건이면 빈 상태를 보여준다
- 일과가 있으면 목록을 보여준다
- 서버 실패 시에도 화면이 뜨고 로컬 호칭을 쓴다
- 아이콘을 SVG 에셋으로 그린다 (코드로 그리지 않는다)

**`test/auth_test.dart`**

- 첫 실행이면 signup → login을 수행한다
- 토큰이 있으면 재로그인하지 않는다
- username이 서버 제약(4~20자)을 지킨다
- 401이면 재발급 후 원요청을 1회 재시도한다
- 재시도가 또 401이면 무한 루프 없이 실패한다

## 작업 순서

1. 인증 (`AuthRepository` · 토큰 저장 · Dio 인터셉터) + 테스트
2. `MemberRepository` (`GET /me`) + `RoutineRepository.getMyRoutines` + 테스트
3. 추천 일과 도메인 + 가로 스크롤 위젯 + 테스트
4. `GuardianHomeScreen` Figma 정합 + 테스트
5. 라우터·에셋 등록, 전체 회귀 확인

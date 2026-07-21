# 트러블슈팅 기록

> 실제로 겪은 문제와 해결법. **규칙은 [../CLAUDE.md](../CLAUDE.md)에 있고, 여기는 기록이다.**
> 에러를 만났을 때 여기서 먼저 찾아본다.

## 기록 템플릿

새 항목을 추가할 땐 아래 형식을 지킨다. **재발 방지 칸을 비우지 않는다** —
기록만 하고 규칙이나 테스트로 이어지지 않으면 같은 문제가 또 난다.

```markdown
## [증상 한 줄]
**언제**: YYYY-MM-DD · 이슈 #N
**증상**: 무엇이 보였나
**원인**: 진짜 원인
**해결**: 무엇을 바꿨나
**재발 방지**: 규칙 / 테스트 / 구조 변경
```

---

## 목차

**디자인 · 렌더링**
- [일러스트가 사각형으로 렌더링됨](#일러스트가-사각형으로-렌더링됨)
- [버튼 enable 색을 잘못 읽음](#버튼-enable-색을-잘못-읽음)
- [로고 폰트를 못 구해 텍스트로 대체함](#로고-폰트를-못-구해-텍스트로-대체함)

**서버 연동**
- [SupportGoal enum 값이 서버와 전부 달랐음](#supportgoal-enum-값이-서버와-전부-달랐음)
- [서버 필드명이 Dart 예약어와 충돌](#서버-필드명이-dart-예약어와-충돌)

**빌드 · 의존성**
- [build_runner AOT 컴파일 실패](#build_runner-aot-컴파일-실패)
- [riverpod_generator / json_serializable 버전 충돌](#riverpod_generator--json_serializable-버전-충돌)
- [Freezed "No named parameter" 오류](#freezed-no-named-parameter-오류)
- [배포된 앱에만 개발자 도구 버튼이 안 보임](#배포된-앱에만-개발자-도구-버튼이-안-보임)

**화면 · 상태**
- [호칭이 비어 조사만 남음](#호칭이-비어-조사만-남음)

**테스트**
- [위젯 테스트에서 .w 사용 시 에러](#위젯-테스트에서-w-사용-시-에러)
- [riverpod 3.x Override 타입 미export](#riverpod-3x-override-타입-미export)
- [테스트가 실제 위젯 배치를 재현하지 않아 3번 연속 놓침](#테스트가-실제-위젯-배치를-재현하지-않아-3번-연속-놓침)

---

## 일러스트가 사각형으로 렌더링됨

**언제**: 2026-07-21 · [#5](https://github.com/Twin-Fang/elum/issues/5)

**증상**: 시작 화면의 병아리 몸통이 둥근 형태가 아니라 화면 전체를 덮는 **사각형**으로 나왔다.

**원인**: Figma 노드 `238:1810`이 `IMAGE-SVG` 타입인데 다운로드하지 않고
`Container` + `RadialGradient`로 흉내냈다. 실제 SVG 안에는 둥근 `path`와
방사형 그라데이션이 함께 들어있었다.

```dart
// ❌ 이렇게 해서 사각형이 됐다
Container(decoration: BoxDecoration(gradient: RadialGradient(...)))
```

**해결**: SVG를 다운로드해 그대로 렌더링.

```dart
SvgPicture.asset(AppAssets.splashChickBody, width: 393.w, fit: BoxFit.fitWidth)
```

**재발 방지**:
- `CLAUDE.md` §2 **에셋 우선 원칙** — 도형을 코드로 그리지 않는다
- `test/splash_screen_test.dart`의 "병아리 몸통을 직접 그리지 않고 SVG로 렌더링한다"

---

## 버튼 enable 색을 잘못 읽음

**언제**: 2026-07-21 · [#1](https://github.com/Twin-Fang/elum/issues/1)

**증상**: 활성 버튼 색을 `#FF8B22`(주황)로 구현했으나 실제 디자인은 `#242634`(짙은 네이비)였다.

**원인**: 온보딩 프레임의 버튼 **인스턴스**가 전부 `Property 1=disable`로 찍혀 있어
enable variant가 없는 줄 알고 브랜드 컬러에서 추론했다.
컴포넌트셋 원본(`187:299`)에는 `enable` / `disable` 두 variant가 모두 정의되어 있었다.

**해결**: 컴포넌트셋 노드를 직접 조회해 실제 값 확인.

| 상태 | 배경 | 텍스트 |
| --- | --- | --- |
| enable | `#242634` | `#FFFFFF` |
| disable | `#818393` | `rgba(255,255,255,0.5)` |

**재발 방지**: `CLAUDE.md` §3 — **인스턴스가 아니라 컴포넌트셋이 원본이다.**
인스턴스는 특정 variant 하나만 보여준다.

---

## 로고 폰트를 못 구해 텍스트로 대체함

**언제**: 2026-07-21 · [#5](https://github.com/Twin-Fang/elum/issues/5)

**증상**: 시작 화면 로고를 `Cloudsofa_namgim` 폰트(64px)로 그려야 하는데
폰트 파일이 없어 일반 폰트 텍스트 "이룸"으로 대체했다.

**원인**: 애초에 폰트가 아니었다. 로고는 별도 **SVG 컴포넌트**(`Component 4`, `262:3806`)로
존재했고, 다국어 로고 이미지였다.

**해결**: `logo_elum.svg` 다운로드 후 `SvgPicture.asset` 사용. 폰트 미확보 문제 자체가 소멸.

**재발 방지**: "폰트가 없다"고 판단하기 전에 **해당 요소가 이미지인지 먼저 확인**한다.
Figma에서 텍스트처럼 보여도 `IMAGE-SVG`인 경우가 있다.

---

## SupportGoal enum 값이 서버와 전부 달랐음

**언제**: 2026-07-21 · [#1](https://github.com/Twin-Fang/elum/issues/1)

**증상**: 클라이언트 enum이 서버와 하나도 일치하지 않았다.

```
클라이언트(틀림): UNDERSTAND_SEQUENCE, PREPARE_NEW_SITUATIONS, COMPLETE_ALONE
서버(실제):       STEP_BY_STEP,        PREPARE_NEW,            INDEPENDENT
```

**원인**: `docs/06-api-spec.md`(기획 초안)를 보고 만들었다. 초안과 실제 구현이 달랐다.

**해결**: `server/src/main/java/com/chuseok22/elumserver/member/infrastructure/entity/SupportGoal.java`를
직접 읽고 맞춤.

**재발 방지**:
- `CLAUDE.md` §4 — **문서가 아니라 서버 코드가 기준**
- `test/onboarding_profile_test.dart`의 "apiValue가 서버 enum name과 일치한다"

> 이 버그는 조용히 실패한다. 서버가 모르는 enum을 받으면 400을 주거나 무시하는데,
> fallback이 있으면 데모는 돌아가서 **틀린 줄도 모른 채 발표할 뻔했다.**

---

## 서버 필드명이 Dart 예약어와 충돌

**언제**: 2026-07-21 · [#4](https://github.com/Twin-Fang/elum/issues/4)

**증상**: `RoutineQuestionResponse.required`를 그대로 옮겼더니 컴파일 에러.

```
error • The operands of the operator '&&' must be assignable to 'bool'
info  • 'required' is deprecated — use the built-in `required` keyword
```

**원인**: Dart의 `required`는 named parameter 키워드다. 필드명으로 쓸 수 없다.

**해결**: 필드는 `isRequired`로 두고, JSON 파싱에서만 서버 키를 읽는다.

```dart
@Default(false) bool isRequired,
// ...
isRequired: json['required'] == true,
```

**재발 방지**: 서버 필드명이 Dart 예약어(`required`, `is`, `in`, `class`, `default` 등)와
겹치면 **필드명만 바꾸고 JSON 키는 서버를 따른다.** 테스트로 매핑을 고정한다.

---

## build_runner AOT 컴파일 실패

**언제**: 2026-07-21 · [#1](https://github.com/Twin-Fang/elum/issues/1)

**증상**:
```
Failed to compile build script. Check builder definitions and
generated script .dart_tool/build/entrypoint/build.dart.
```
에러 내용이 나오지 않아 원인 파악이 어려웠다.

**원인**: `flutter_secure_storage`가 의존하는 `objective_c` 패키지에 **build hook**(`hook/build.dart`)이 있다.
Dart 3.10부터 `dart compile aot-snapshot`이 build hook을 가진 프로젝트를 거부하는데,
`build_runner 2.15.1`이 여전히 그 명령을 쓴다.

**진단 방법**:
```bash
# 실제 에러를 보려면 AOT 컴파일을 직접 실행
dart compile aot-snapshot .dart_tool/build/entrypoint/build.dart -o /tmp/build.aot
# → 'dart compile' does not support build hooks, use 'dart build' instead.

# build hook을 가진 패키지 찾기
python3 -c "
import json,os
pc=json.load(open('.dart_tool/package_config.json'))
for p in pc['packages']:
    root=p['rootUri'].replace('file://','')
    if not os.path.isabs(root): root=os.path.abspath(os.path.join('.dart_tool',root))
    if os.path.exists(os.path.join(root,'hook/build.dart')): print(p['name'])
"
```

**해결**: `flutter_secure_storage` 제거. PIN은 `shared_preferences`에 저장하되
`LocalStorage` 인터페이스로 감싸 나중에 교체 가능하게 했다.

**재발 방지**: 새 패키지를 추가한 뒤 `dart run build_runner build`가 깨지면
**그 패키지의 build hook을 먼저 의심한다.**

> ⚠️ **미해결 과제**: PIN이 평문 저장된다. 보안 해커톤 특성상 발표 전 재검토 필요.

---

## riverpod_generator / json_serializable 버전 충돌

**언제**: 2026-07-21 · [#1](https://github.com/Twin-Fang/elum/issues/1)

**증상**: `flutter pub add`가 장문의 version solving 실패로 끝난다.

**원인**: `flutter_riverpod 3.3.2`가 요구하는 `analyzer` 버전과
`riverpod_generator`/`json_serializable`이 요구하는 버전이 겹치지 않는다.

**해결**: 두 패키지 모두 제외.
- provider는 손으로 선언 (`NotifierProvider<T, S>(T.new)`)
- JSON 파싱은 모델의 `fromJson`에 직접 작성 (필드가 적어 충분하다)
- **Freezed는 정상 동작**하므로 불변 모델·`copyWith`는 그대로 쓴다

**재발 방지**: 코드 생성 패키지를 추가하기 전에 `--dry-run`으로 먼저 확인한다.

---

## Freezed "No named parameter" 오류

**언제**: 2026-07-21

**증상**: 모델에 분명히 있는 필드인데 "No named parameter with the name 'x'" 에러.

**원인**: `@freezed` 모델을 수정한 뒤 코드 생성을 다시 돌리지 않았다.
`*.freezed.dart`가 낡은 상태로 남아있다.

**해결**:
```bash
dart run build_runner build --delete-conflicting-outputs
```

**재발 방지**: **`@freezed` 클래스를 건드렸으면 무조건 build_runner를 돌린다.**
에러 메시지가 원인을 가리키지 않으므로 반사적으로 실행하는 편이 빠르다.

---

## 배포된 앱에만 개발자 도구 버튼이 안 보임

**언제**: 2026-07-21 · [#13](https://github.com/Twin-Fang/elum/issues/13)

**증상**: 로컬 `.env`에 `ELUM_SHOW_DEV_TOOLS=true`를 넣었는데도 Firebase·TestFlight로
받은 앱에서 플로팅 버튼이 보이지 않았다. 로컬 실행에서는 정상이라 코드를 계속 의심했다.

**원인**: **배포 빌드의 `.env`는 로컬 파일이 아니라 GitHub Secret에서 만들어진다.**
`.env`는 `.gitignore` 대상이라 커밋되지도, 빌드 아티팩트로 옮겨지지도 않는다.
워크플로우의 `Create .env file` 스텝이 Secret `ENV_FILE`(없으면 `ENV`)로 새로 쓰므로,
로컬 파일을 아무리 고쳐도 배포 앱에는 반영되지 않는다. Secret 값이 `false`였다.

코드(`AppConfig.showDevTools`·`DevToolsOverlay`)에는 문제가 없었다. 이 값만은 의도적으로
`kDebugMode` 게이트를 걸지 않아 릴리스 빌드에서도 동작하게 되어 있다.

**왜 찾기 어려웠나**: Secret은 **값을 읽어 확인할 수 없다.** 등록 여부만 보이고 내용은
쓰기 전용이라, 어긋나 있어도 눈으로 대조할 방법이 없다.

**해결**: 빌드 워크플로우 4개(총 7곳)에서 `.env` 생성 직후 이 키를 강제로 덮어쓴다.
Secret 값과 무관하게 항상 켜진다.

```yaml
- name: Force enable dev tools (hackathon)
  run: |
    sed -i '/^ELUM_SHOW_DEV_TOOLS=/d' .env   # macOS 러너는 sed -i ''
    echo 'ELUM_SHOW_DEV_TOOLS=true' >> .env
    grep '^ELUM_SHOW_DEV_TOOLS=' .env        # 주입 실패 시 스텝을 실패시킨다
```

**재발 방지**

- **`.env` 값이 배포 앱에서 다르게 동작하면 Secret부터 의심한다.** 코드가 아니다.
- `.env` 생성은 **잡마다 따로** 일어난다. 실제 빌드가 도는 잡에 주입하지 않으면 반영되지
  않으므로 스텝을 옮기거나 지울 때 잡 단위로 확인한다.
- 마지막 줄의 `grep`이 검증 장치다. 값이 안 들어가면 exit 1로 스텝이 실패해 조용히
  넘어가지 않는다. 이 줄을 지우지 않는다.
- 정식 출시 전 `Force enable dev tools (hackathon)` 스텝을 모두 삭제하고 Secret을
  `false`로 되돌린다.

---

## 호칭이 비어 조사만 남음

**언제**: 2026-07-21 · [#3](https://github.com/Twin-Fang/elum/issues/3)

**증상**: 목표 화면 제목이 `"의 어떤 순간을 도와주고 싶으신가요?"`로 나왔다.

**원인**: 제목에 `${profile.childNickname}`을 그대로 썼는데, 딥링크나 중간 진입으로
호칭 입력을 건너뛰면 빈 문자열이 되어 조사만 남는다.

**해결**: 모델에 `displayName` getter 추가. 비어있으면 `'우리 아이'`를 준다.

**재발 방지**:
- 화면 문구에 사용자 입력을 넣을 땐 **빈 값일 때를 항상 고려**한다
- 라우터 redirect로 중간 진입 차단
- `test/onboarding_profile_test.dart`의 "호칭이 없으면 제목용 대체어를 준다"

---

## 위젯 테스트에서 .w 사용 시 에러

**언제**: 2026-07-21 · [#5](https://github.com/Twin-Fang/elum/issues/5)

**증상**: `.w`/`.h`/`.sp`를 쓰는 화면의 위젯 테스트가 실패한다.

**원인**: `ScreenUtil`이 초기화되지 않았다. 앱에서는 `app.dart`의 `ScreenUtilInit`이
처리하지만 테스트는 그 위젯을 거치지 않는다.

**해결**: 테스트에서도 `ScreenUtilInit`으로 감싼다.

```dart
ScreenUtilInit(
  designSize: const Size(393, 852),
  builder: (context, child) => MaterialApp.router(...),
)
```

**재발 방지**: 화면 위젯 테스트 헬퍼를 `test/helpers/`에 두고 재사용한다.

---

## riverpod 3.x Override 타입 미export

**언제**: 2026-07-21 · [#5](https://github.com/Twin-Fang/elum/issues/5)

**증상**: 테스트 헬퍼에서 `Override` 반환 타입을 명시하면 `Undefined class 'Override'`.

**원인**: `flutter_riverpod 3.3.2`가 `Override` 타입을 export하지 않는다.
타입 자체는 `riverpod` 내부에 존재하지만 공개 API가 아니다.

**해결**: 반환 타입을 명시하지 않고 추론에 맡긴다. lint만 무시한다.

```dart
// ignore: strict_top_level_inference
testStorageOverride({bool onboardingCompleted = false}) {
  return localStorageProvider.overrideWithValue(InMemoryStorage(...));
}
```

**재발 방지**: riverpod 관련 타입을 명시하기 전에 export 여부를 확인한다.

---

## 테스트가 실제 위젯 배치를 재현하지 않아 3번 연속 놓침

**언제**: 2026-07-21 · 이슈 #13
**증상**: 개발자 도구 오버레이가 테스트는 전부 통과했는데 실기기에서 누를 때마다 터졌다.
같은 뿌리의 예외가 **세 번 연속** 다른 얼굴로 나왔다.

```
1차: Navigator operation requested with a context that does not include a Navigator.
2차: A HeroController can not be shared by multiple Navigators.
3차: No GoRouter found in context
```

**원인**: 테스트가 실제 배치를 흉내내지 않았다.

| | 테스트 | 실제 (`app.dart`) |
| --- | --- | --- |
| 배치 | `MaterialApp(home: DevToolsOverlay(...))` | `MaterialApp.router(builder: ...)` |
| Navigator·Overlay·GoRouter 기준 | **안쪽** → 찾아짐 | **바깥쪽** → 못 찾음 |

`MaterialApp`의 `builder`에 놓인 위젯은 Navigator·Overlay·GoRouter보다 **위**에 있다.
`showModalBottomSheet` · `showDialog` · `Overlay.of` · `context.go` 전부 조상에서
찾으므로 셋 다 실패한다. 테스트가 `home:`에 넣으면 이 조건이 성립하지 않아 통과해버린다.

**해결**:

1. 조상에 의존하지 않도록 구조 변경 — 패널을 `Stack`에 직접 그리고, 하위 화면 전환은
   라우팅 대신 내부 상태(enum)로 처리
2. 화면 이동은 `context.go` 대신 **콜백 주입** — 라우터를 가진 `app.dart`가
   `onNavigate: _router.go`를 넘긴다
3. 테스트를 실제 배치대로 고침 — `builder:`에 넣고, 이동이 걸린 기능은
   `MaterialApp.router` + `GoRouter`로 구성한 별도 헬퍼로 검증

**재발 방지**:

- **위젯 테스트는 그 위젯이 실제로 놓이는 위치와 같은 곳에 배치한다.**
  `home:`에 넣는 것이 편하지만 `builder:`에 놓일 위젯이면 아무것도 지켜주지 못한다.
- **고쳤다고 생각하면 수정을 되돌려 테스트가 실패하는지 확인한다.** 이번에도
  `onNavigate` → `context.go`로 되돌려 `No GoRouter found in context`가 재현되는 것을
  확인한 뒤에야 통과를 신뢰했다.
- `tester.takeException()`을 `expect(..., isNull)`로 명시 검증한다. 위젯 테스트는
  예외를 삼키고 지나갈 수 있다.
- 관련 테스트: `test/dev_tools_overlay_test.dart`의 `실제 라우터 환경 (MaterialApp.router)` 그룹

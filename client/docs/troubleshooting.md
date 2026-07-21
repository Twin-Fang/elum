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

**화면 · 상태**
- [호칭이 비어 조사만 남음](#호칭이-비어-조사만-남음)

**테스트**
- [위젯 테스트에서 .w 사용 시 에러](#위젯-테스트에서-w-사용-시-에러)
- [riverpod 3.x Override 타입 미export](#riverpod-3x-override-타입-미export)

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

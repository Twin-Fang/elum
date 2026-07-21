# 온보딩_이름 화면 Figma 구현 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Figma `온보딩_이름`(204:991 빈 상태 / 204:1174 입력 완료 상태)대로 이름 입력
화면을 완성한다 — 입력 필드 좌측 아이콘 추가와 placeholder 좌측 정렬.

**Architecture:** 새 화면을 만들지 않는다. 기존 `ElumTextField`에 아이콘 파라미터
`leadingIconAssetPath`를 추가하고, 아이콘 유무로 텍스트 정렬을 자동 판단하는 getter
`resolvedTextAlign`을 둔다. `NameScreen`은 파라미터 한 줄만 넘긴다. 204:1174는
같은 화면의 상태 전이이므로 회귀 테스트로만 고정한다.

**Tech Stack:** Flutter · Riverpod 3.x · go_router · flutter_svg · flutter_screenutil ·
freezed · flutter_test

## Global Constraints

- 작업 브랜치는 `develop`이다. `main`에 직접 커밋하지 않는다.
- 모든 명령은 `client/` 디렉터리에서 실행한다. (`cd client` 먼저)
- 색상은 `Color(0x...)`를 위젯에 직접 쓰지 않고 `context.colors` 토큰을 경유한다.
- 에셋 경로는 `AppAssets` 상수를 경유한다. 위젯에 `'assets/images/...'` 문자열을 쓰지 않는다.
- 주석은 한국어로, WHY 중심으로 간결하게 쓴다.
- 커밋 메시지에 `Co-Authored-By` 태그를 넣지 않는다.
- `git push`는 사용자가 명시적으로 요청할 때만 한다. 이 계획에는 push 단계가 없다.
- 입력값 색상은 Figma의 `#000000`이 아니라 `context.colors.textPrimary`(`#242634`)를 쓴다.
- `pubspec.yaml`은 `assets/images/`를 디렉터리 단위로 등록하고 있으므로 수정하지 않는다.

## File Structure

| 파일 | 책임 | 상태 |
| --- | --- | --- |
| `client/assets/images/icon_child_head.svg` | 입력 필드 좌측 아이콘 (40×40) | 생성 |
| `client/lib/core/assets/app_assets.dart` | 에셋 경로 상수 | 수정 — 상수 1개 추가 |
| `client/lib/core/widgets/elum_text_field.dart` | 입력 필드 위젯 | 수정 — 파라미터 2개 + getter 1개 |
| `client/lib/features/onboarding/presentation/name_screen.dart` | 이름 입력 화면 | 수정 — 1줄 |
| `client/test/helpers/svg_finder.dart` | SVG 에셋 Finder 헬퍼 | 생성 (splash 테스트에서 추출) |
| `client/test/splash_screen_test.dart` | 시작 화면 테스트 | 수정 — 헬퍼 추출분 반영 |
| `client/test/elum_text_field_test.dart` | 정렬 판단 규칙 단위 테스트 | 생성 |
| `client/test/name_screen_test.dart` | 두 Figma 상태 위젯 테스트 | 생성 |

**Task 순서 근거:** Task 1(헬퍼 추출)은 Task 3·4가 함께 쓰므로 먼저 한다.
Task 2(위젯 API)는 화면이 의존하므로 화면보다 먼저 한다. Task 3(에셋+화면)이
끝나야 Task 4의 위젯 테스트가 의미를 가진다.

---

### Task 1: SVG Finder 헬퍼 추출

`splash_screen_test.dart` 안에 있는 `_svgWithAsset`을 공유 헬퍼로 옮긴다.
Task 3·4의 테스트가 같은 Finder를 쓴다. 복사해두면 한쪽만 고쳐지는 사고가 난다.

**Files:**
- Create: `client/test/helpers/svg_finder.dart`
- Modify: `client/test/splash_screen_test.dart` (파일 끝의 `_svgWithAsset` 제거, import 추가)

**Interfaces:**
- Consumes: 없음
- Produces: `Finder svgWithAsset(String assetPath)` — 지정한 에셋 경로를 쓰는
  `SvgPicture` 위젯을 찾는다. Task 3·4가 쓴다.

- [ ] **Step 1: 헬퍼 파일 생성**

`client/test/helpers/svg_finder.dart`:

```dart
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// 특정 에셋 경로를 쓰는 SvgPicture를 찾는다.
///
/// Figma 도형을 Container로 직접 그리다 형태가 어긋나는 사고를 막기 위해,
/// "에셋으로 렌더링되는가"를 테스트가 직접 확인한다.
Finder svgWithAsset(String assetPath) {
  return find.byWidgetPredicate((widget) {
    if (widget is! SvgPicture) return false;
    final loader = widget.bytesLoader;
    return loader is SvgAssetLoader && loader.assetName == assetPath;
  });
}
```

- [ ] **Step 2: splash 테스트에서 로컬 헬퍼 제거**

`client/test/splash_screen_test.dart` 파일 맨 아래의 아래 블록을 **삭제**한다:

```dart
/// 특정 에셋 경로를 쓰는 SvgPicture를 찾는다.
Finder _svgWithAsset(String assetPath) {
  return find.byWidgetPredicate((widget) {
    if (widget is! SvgPicture) return false;
    final loader = widget.bytesLoader;
    return loader is SvgAssetLoader && loader.assetName == assetPath;
  });
}
```

같은 파일 상단 import 블록에 아래 한 줄을 추가한다 (`import 'helpers/test_storage.dart';` 옆):

```dart
import 'helpers/svg_finder.dart';
```

파일 본문의 `_svgWithAsset(` 호출 4곳을 `svgWithAsset(`으로 바꾼다 (언더스코어 제거).
해당 호출은 아래 4곳이다:

```dart
expect(svgWithAsset(AppAssets.logo), findsOneWidget);
expect(svgWithAsset(AppAssets.splashChickBody), findsOneWidget);
expect(svgWithAsset(AppAssets.splashHill), findsOneWidget);
expect(svgWithAsset(AppAssets.splashStar), findsOneWidget);
```

`flutter_svg` import가 더 이상 쓰이지 않으면 analyzer가 경고하므로 함께 제거한다.

- [ ] **Step 3: 기존 테스트가 그대로 통과하는지 확인**

Run: `cd client && flutter test test/splash_screen_test.dart`
Expected: PASS — 8개 테스트 모두 통과. 리팩터링이므로 동작이 변하면 안 된다.

- [ ] **Step 4: analyze로 미사용 import 확인**

Run: `cd client && flutter analyze test/splash_screen_test.dart`
Expected: `No issues found!`

- [ ] **Step 5: 커밋**

```bash
cd client && git add test/helpers/svg_finder.dart test/splash_screen_test.dart
git commit -m "refactor(test): SVG Finder 헬퍼를 test/helpers로 추출

이름 화면 테스트도 같은 Finder를 쓴다. 복사하면 한쪽만 고쳐진다."
```

---

### Task 2: `ElumTextField`에 아이콘·정렬 판단 추가

정렬 자동 판단 규칙을 먼저 테스트로 고정하고 위젯을 고친다.

**Files:**
- Create: `client/test/elum_text_field_test.dart`
- Modify: `client/lib/core/widgets/elum_text_field.dart`

**Interfaces:**
- Consumes: 없음 (기존 `context.colors` / `context.space` / `context.typo` 토큰만 사용)
- Produces:
  - `ElumTextField({Key? key, required String hintText, TextEditingController? controller,
    ValueChanged<String>? onChanged, String? leadingIconAssetPath, TextAlign? explicitTextAlign})`
  - `TextAlign get resolvedTextAlign` — 아이콘이 있으면 `TextAlign.left`,
    없으면 `TextAlign.center`. `explicitTextAlign`이 있으면 그 값이 이긴다.
  - 기존 `textAlign` 파라미터는 **제거**된다. 현재 호출부는 `NameScreen` 한 곳뿐이고
    기본값만 쓰고 있어 마이그레이션 부담이 없다.

- [ ] **Step 1: 실패하는 테스트 작성**

`client/test/elum_text_field_test.dart`:

```dart
import 'package:elum/core/widgets/elum_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 정렬 자동 판단 규칙을 고정한다.
///
/// 아이콘은 왼쪽에 붙는데 텍스트만 가운데 뜨는 조합은 디자인상 존재하지 않는다.
/// 호출부가 정렬을 매번 넘기지 않아도 되도록 위젯이 스스로 판단한다.
void main() {
  group('ElumTextField 정렬 판단', () {
    test('아이콘이 있으면 좌측 정렬이다', () {
      const field = ElumTextField(
        hintText: '이름을 입력해주세요',
        leadingIconAssetPath: 'assets/images/icon_child_head.svg',
      );

      expect(field.resolvedTextAlign, TextAlign.left);
    });

    test('아이콘이 없으면 중앙 정렬이다', () {
      const field = ElumTextField(hintText: '이름을 입력해주세요');

      expect(field.resolvedTextAlign, TextAlign.center);
    });

    test('explicitTextAlign을 넘기면 자동 판단을 이긴다', () {
      // 아이콘이 있어도 호출부가 명시하면 그 값을 쓴다
      const field = ElumTextField(
        hintText: '이름을 입력해주세요',
        leadingIconAssetPath: 'assets/images/icon_child_head.svg',
        explicitTextAlign: TextAlign.center,
      );

      expect(field.resolvedTextAlign, TextAlign.center);
    });
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `cd client && flutter test test/elum_text_field_test.dart`
Expected: FAIL — 컴파일 에러. `leadingIconAssetPath`, `explicitTextAlign`,
`resolvedTextAlign`이 아직 없다는 내용이어야 한다.

- [ ] **Step 3: 위젯 구현**

`client/lib/core/widgets/elum_text_field.dart` 전체를 아래로 교체한다:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme_context_ext.dart';

/// 입력 필드. Figma 기준 344×68 / radius 20 / 흰 배경 + 1px 테두리.
///
/// 왼쪽 아이콘은 선택이다. 아이콘이 붙으면 텍스트가 좌측 정렬로 바뀐다
/// (Figma `온보딩_이름` 204:991 — placeholder가 아이콘 우측 x=90에서 시작).
class ElumTextField extends StatelessWidget {
  const ElumTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.leadingIconAssetPath,
    this.explicitTextAlign,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// 필드 왼쪽에 붙는 SVG 아이콘 경로. `AppAssets.inputFieldIcon*`을 넘긴다.
  /// null이면 아이콘 영역 자체가 생기지 않는다.
  final String? leadingIconAssetPath;

  /// 정렬을 강제로 지정할 때만 넘긴다.
  /// 평소에는 null로 두고 [resolvedTextAlign]의 판단에 맡긴다.
  final TextAlign? explicitTextAlign;

  /// Figma 아이콘 크기 (40×40) — 좌표에서 역산한 값이라 상수로 고정한다
  static const _leadingIconSize = 40.0;

  /// 필드 좌측(x=24) → 아이콘 좌측(x=38)
  static const _leadingIconLeftGap = 14.0;

  /// 아이콘 우측(x=78) → 텍스트 좌측(x=90)
  static const _leadingIconRightGap = 12.0;

  /// 아이콘이 있으면 좌측, 없으면 중앙 정렬.
  /// 아이콘은 왼쪽에 붙는데 텍스트만 가운데 뜨는 조합은 디자인상 존재하지 않으므로
  /// 호출부가 매번 정렬을 넘기게 하지 않는다.
  TextAlign get resolvedTextAlign =>
      explicitTextAlign ??
      (leadingIconAssetPath != null ? TextAlign.left : TextAlign.center);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return SizedBox(
      height: space.fieldH,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: resolvedTextAlign,
        textAlignVertical: TextAlignVertical.center,
        style: context.typo.input.copyWith(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: context.typo.input.copyWith(color: colors.textPlaceholder),
          filled: true,
          fillColor: colors.surface,
          contentPadding: EdgeInsets.symmetric(horizontal: space.md),
          prefixIcon: _buildLeadingIcon(),
          // 기본 최소폭 48이 적용되면 Figma 좌표가 밀린다
          prefixIconConstraints: const BoxConstraints(),
          border: _border(colors.border, space.fieldRadius),
          enabledBorder: _border(colors.border, space.fieldRadius),
          focusedBorder: _border(colors.selectedBorder, space.fieldRadius, width: 2),
        ),
      ),
    );
  }

  Widget? _buildLeadingIcon() {
    final assetPath = leadingIconAssetPath;
    if (assetPath == null) return null;

    return Padding(
      padding: EdgeInsets.only(
        left: _leadingIconLeftGap.w,
        right: _leadingIconRightGap.w,
      ),
      child: SvgPicture.asset(
        assetPath,
        width: _leadingIconSize.w,
        height: _leadingIconSize.w,
      ),
    );
  }

  OutlineInputBorder _border(Color color, double radius, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd client && flutter test test/elum_text_field_test.dart`
Expected: PASS — 3개 테스트 통과.

- [ ] **Step 5: 기존 화면이 깨지지 않았는지 확인**

`textAlign` 파라미터를 제거했으므로 호출부가 남아있으면 컴파일이 깨진다.

Run: `cd client && flutter analyze lib`
Expected: `No issues found!`

analyzer가 `name_screen.dart`에서 `textAlign` 관련 에러를 내면, 현재 코드가
그 파라미터를 넘기고 있다는 뜻이다. Task 3에서 어차피 고치므로 여기서는
해당 인자만 지운다.

- [ ] **Step 6: 커밋**

```bash
cd client && git add lib/core/widgets/elum_text_field.dart test/elum_text_field_test.dart
git commit -m "feat(client): ElumTextField에 좌측 아이콘·정렬 자동 판단 추가

leadingIconAssetPath가 있으면 좌측 정렬로 바꾼다.
아이콘+중앙정렬은 유효한 디자인 조합이 아니라 호출부에 맡기지 않는다.
explicitTextAlign으로 override 경로는 열어둔다."
```

---

### Task 3: 아이콘 에셋 추가 + `NameScreen` 연결

**Files:**
- Create: `client/assets/images/icon_child_head.svg` (Figma export)
- Modify: `client/lib/core/assets/app_assets.dart`
- Modify: `client/lib/features/onboarding/presentation/name_screen.dart`

**Interfaces:**
- Consumes: Task 2의 `ElumTextField.leadingIconAssetPath`
- Produces: `AppAssets.inputFieldIconChildName` — Task 4의 테스트가 참조한다.

- [ ] **Step 1: Figma에서 아이콘 SVG를 내려받는다**

`mcp__figma__download_figma_images` 툴을 아래 인자로 호출한다:

- `fileKey`: `VSmGuv1iuOpLZmp6QeBHWr`
- `localPath`: `/Users/suhsaechan/Desktop/Programming/project/elum_codegate2026/client/assets/images`
- `nodes`: `[{ "nodeId": "204:999", "fileName": "icon_child_head.svg" }]`

204:999(`Group 5`)는 `IMAGE-SVG` 노드라 원 배경과 어린이 머리 아이콘이 한 파일로
나온다. 원을 Flutter `Container`로 다시 그리지 않는다 — 스플래시에서 형태가
어긋나는 사고를 이미 겪었다.

204:1174의 `Group 4`(204:1182)는 같은 아이콘이므로 따로 받지 않는다.

- [ ] **Step 2: 내려받은 파일 확인**

Run: `cd client && ls -la assets/images/icon_child_head.svg && head -c 300 assets/images/icon_child_head.svg`

Expected: 파일이 존재하고 `<svg` 로 시작한다. 내용에 `40`(viewBox 크기)과
노란 계열 색상(`#FFD629` 또는 `#F3C500`)이 보이면 정상이다.
파일이 없거나 0바이트면 Step 1을 다시 실행한다.

- [ ] **Step 3: `AppAssets`에 상수 추가**

`client/lib/core/assets/app_assets.dart`의 마지막 `splashCenter` 상수 아래,
클래스 닫는 중괄호 직전에 추가한다:

```dart

  // --- 입력 필드 아이콘 ---

  /// 아이 이름 입력 필드의 좌측 아이콘 (40×40).
  /// 노란 원 배경(rgba(255,214,41,0.3))과 어린이 머리(#F3C500)가 SVG 안에 함께 있다.
  /// Figma `온보딩_이름`(204:991)의 Group 5.
  static const inputFieldIconChildName = '$_images/icon_child_head.svg';
```

`inputFieldIcon` 접두어를 쓴다 — 앞으로 일과 입력 등 다른 필드 아이콘이 늘어나면
`inputFieldIconRoutine`처럼 같은 계열로 붙어 상수 이름만 보고 용도를 알 수 있다.

- [ ] **Step 4: `NameScreen`에 아이콘 연결**

`client/lib/features/onboarding/presentation/name_screen.dart`의 `ElumTextField`
호출을 아래로 바꾼다:

```dart
          ElumTextField(
            controller: _controller,
            hintText: '이름을 입력해주세요',
            leadingIconAssetPath: AppAssets.inputFieldIconChildName,
            onChanged: ref.read(onboardingProvider.notifier).setNickname,
          ),
```

같은 파일 상단 import 블록에 추가한다:

```dart
import '../../../core/assets/app_assets.dart';
```

정렬은 `resolvedTextAlign`이 알아서 좌측으로 바꾸므로 넘기지 않는다.

- [ ] **Step 5: 분석·빌드 확인**

Run: `cd client && flutter analyze lib`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
cd client && git add assets/images/icon_child_head.svg lib/core/assets/app_assets.dart lib/features/onboarding/presentation/name_screen.dart
git commit -m "feat(client): 이름 입력 필드에 아이 아이콘 추가

Figma 온보딩_이름(204:991) Group 5를 SVG로 내려받아 연결한다.
아이콘이 붙으면서 placeholder가 Figma대로 좌측 정렬된다."
```

---

### Task 4: 두 Figma 상태 위젯 테스트

204:991(빈 상태)과 204:1174(입력 완료 상태)를 각각 group으로 고정한다.

**Files:**
- Create: `client/test/name_screen_test.dart`

**Interfaces:**
- Consumes: `svgWithAsset` (Task 1), `AppAssets.inputFieldIconChildName` (Task 3),
  `Routes.onboardingName` / `Routes.onboardingGoals`, `testStorageOverride`
- Produces: 없음 (최종 태스크)

- [ ] **Step 1: 테스트 작성**

`client/test/name_screen_test.dart`:

```dart
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/presentation/name_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 이름 화면은 Figma `온보딩_이름` 두 프레임을 따른다.
///
/// - 204:991  빈 상태 (placeholder · CTA disable)
/// - 204:1174 입력 완료 상태 (입력값 · CTA enable)
///
/// 두 프레임은 같은 화면의 상태 전이다. 별도 화면을 만들지 않고
/// 상태가 올바르게 갈리는지를 여기서 고정한다.
void main() {
  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: Routes.onboardingName,
      routes: [
        GoRoute(
          path: Routes.onboardingName,
          builder: (context, state) => const NameScreen(),
        ),
        GoRoute(
          path: Routes.onboardingGoals,
          builder: (context, state) => const Scaffold(body: Text('목표 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// CTA 활성 여부는 onPressed가 null인지로 판정한다.
  /// 색상값을 직접 비교하면 토큰이 바뀔 때마다 테스트가 깨진다.
  bool isNextButtonEnabled(WidgetTester tester) {
    final button = tester.widget<ElumButton>(find.byType(ElumButton));
    return button.onPressed != null;
  }

  group('빈 상태 (204:991)', () {
    testWidgets('Figma 문구 3종이 보인다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('아이를 어떻게\n불러드릴까요?'), findsOneWidget);
      expect(find.text('정확한 실명이 아니어도 괜찮아요'), findsOneWidget);
      expect(find.text('이름을 입력해주세요'), findsOneWidget);
    });

    testWidgets('필드 아이콘은 직접 그리지 않고 SVG 에셋으로 렌더링한다', (tester) async {
      // 노란 원과 아이콘이 SVG 안에 함께 있다.
      // Container + BoxDecoration으로 흉내내면 형태가 어긋난다.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        svgWithAsset(AppAssets.inputFieldIconChildName),
        findsOneWidget,
      );
    });

    testWidgets('입력 전에는 다음 버튼이 비활성이다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('다음'), findsOneWidget);
      expect(isNextButtonEnabled(tester), isFalse);
    });
  });

  group('입력 완료 상태 (204:1174)', () {
    testWidgets('한 글자 입력하면 다음 버튼이 활성된다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      expect(isNextButtonEnabled(tester), isTrue);
    });

    testWidgets('입력하면 placeholder가 사라지고 입력값이 보인다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      expect(find.text('하늘이'), findsOneWidget);
      expect(find.text('이름을 입력해주세요'), findsNothing);
    });

    testWidgets('입력 후에도 필드 아이콘은 그대로 있다', (tester) async {
      // 204:1174에도 같은 아이콘(Group 4)이 있다.
      // 상태가 바뀌었다고 아이콘이 사라지면 안 된다.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      expect(
        svgWithAsset(AppAssets.inputFieldIconChildName),
        findsOneWidget,
      );
    });

    testWidgets('공백만 입력하면 활성되지 않는다', (tester) async {
      // canProceedFromName이 trim()으로 판단한다
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      expect(isNextButtonEnabled(tester), isFalse);
    });

    testWidgets('입력 후 다음을 누르면 목표 화면으로 간다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('목표 화면'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행**

Run: `cd client && flutter test test/name_screen_test.dart`
Expected: PASS — 7개 테스트 통과.

Task 2·3이 끝난 상태이므로 통과해야 한다. 실패하면 원인별 대응:

| 실패 내용 | 원인 | 대응 |
| --- | --- | --- |
| `svgWithAsset(...)` findsNothing | 에셋 미등록 또는 경로 오타 | Task 3 Step 2·3 재확인 |
| `find.text('아이를 어떻게\n불러드릴까요?')` findsNothing | 제목 줄바꿈 위치가 다름 | `name_screen.dart`의 title 문자열 확인 |
| 버튼이 계속 비활성 | `onChanged`가 notifier에 연결 안 됨 | `name_screen.dart`의 `onChanged` 확인 |

- [ ] **Step 3: 전체 테스트 스위트 실행**

Run: `cd client && flutter test`
Expected: 모든 테스트 PASS. Task 1의 헬퍼 추출과 Task 2의 `textAlign` 파라미터
제거가 다른 테스트를 깨지 않았는지 여기서 확인한다.

- [ ] **Step 4: 전체 분석**

Run: `cd client && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: 커밋**

```bash
cd client && git add test/name_screen_test.dart
git commit -m "test(client): 이름 화면 두 Figma 상태 회귀 테스트

204:991 빈 상태와 204:1174 입력 완료 상태를 group으로 나눠 고정한다.
입력 후에도 아이콘이 남아있는지를 명시적으로 검증한다 —
204:1174에도 같은 아이콘이 있다."
```

---

## 완료 조건

모든 태스크가 끝나면 아래를 만족한다.

- [ ] `cd client && flutter test` 전체 통과
- [ ] `cd client && flutter analyze` 이슈 없음
- [ ] 시작 화면 → `시작하기` → 이름 화면 진입 시 필드 좌측에 노란 원 아이콘이 보인다
- [ ] placeholder가 아이콘 우측에서 좌측 정렬로 시작한다
- [ ] 이름 입력 전 `다음` 버튼이 회색(비활성), 입력 후 진한 남색(활성)으로 바뀐다
- [ ] `다음`을 누르면 목표 화면으로 이동한다

## 이 계획에 없는 것

- `git push` — 사용자가 명시적으로 요청할 때만 한다
- 뒤로가기 버튼 — Figma `온보딩_이름` 두 프레임 모두에 없다
- 온보딩 진행 표시(`1 / 2`) — `docs/03-screens.md` 러프 명세에는 있으나
  Figma 확정본에 없다. Figma를 따른다.
- 상태바·홈 인디케이터 — iOS가 그린다
- `leadingIconSize` 파라미터 — 지금은 40 고정으로 충분하다 (YAGNI)

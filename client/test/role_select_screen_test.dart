import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/auth/presentation/role_select_screen.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 역할 선택 (이슈 #212 · 명세 §4-3).
///
/// 약관 동의 뒤 보호자와 이룸이가 갈라지는 지점이다. 여기가 막히면 이룸이
/// 휴대폰은 앱에 들어올 길이 없다 — 지금까지 개발자 도구로만 갈 수 있었다.
void main() {
  useFigmaViewport();

  late InMemoryStorage storage;

  setUp(() => storage = InMemoryStorage());

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.roleSelect,
      routes: [
        GoRoute(
          path: Routes.roleSelect,
          builder: (context, state) => const RoleSelectScreen(),
        ),
        GoRoute(
          path: Routes.onboardingName,
          builder: (context, state) => const Scaffold(body: Text('이름 화면')),
        ),
        GoRoute(
          path: Routes.linkEnter,
          // 실제 화면 대신 뒤로가기만 가진 대역 — 여기서 보려는 건
          // "돌아올 수 있는가"이지 연결 화면의 생김새가 아니다.
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('연결 암호 넣기'),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('뒤로'),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('누구인지만 묻는다 — 연결 암호를 말하지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('서비스를\n누가 사용하나요?'), findsOneWidget);
    expect(find.text('보호자예요'), findsOneWidget);
    expect(find.text('이룸이예요'), findsOneWidget);

    // 처음 보는 이룸이는 암호를 받은 적이 없다. 여기서 말하면 막힌다.
    expect(find.textContaining('암호'), findsNothing);
    expect(find.textContaining('코드'), findsNothing);
  });

  testWidgets('되돌릴 수 있다는 것을 고르기 전에 말한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('나중에 바꿀 수 있어요'), findsOneWidget);
  });

  testWidgets('다음 버튼이 없다 — 탭하면 바로 넘어간다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('다음'), findsNothing);

    await tester.tap(find.text('보호자예요'));
    await tester.pumpAndSettle();

    expect(find.text('이름 화면'), findsOneWidget);
  });

  testWidgets('보호자를 고르면 역할이 저장된다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('보호자예요'));
    await tester.pumpAndSettle();

    expect(storage.selectedRole, AppRole.guardian.storageValue);
  });

  testWidgets('이룸이를 고르면 연결 암호 넣기로 간다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('이룸이예요'));
    await tester.pumpAndSettle();

    expect(find.text('연결 암호 넣기'), findsOneWidget);
    expect(storage.selectedRole, AppRole.elumi.storageValue);
  });

  testWidgets('잘못 골라도 갇히지 않는다 — 연결 화면에서 되돌아온다 (이슈 #212)',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('이룸이예요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    // go로 갈아끼웠다면 스택이 없어 pop이 실패하고 연결 화면에 그대로 남는다
    // (이슈 #194와 같은 함정). push로 얹었기에 돌아올 수 있다.
    expect(find.text('보호자예요'), findsOneWidget);
  });

  testWidgets('역할만 골랐을 때는 이룸이 휴대폰으로 표시하지 않는다', (tester) async {
    // 여기서 isElumiDevice를 세우면 라우터 가드(이슈 #206)가 곧바로 다시
    // 연결 화면으로 잡아가 뒤로가기가 막힌다. 그 값은 연결 성공 시에만 선다.
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('이룸이예요'));
    await tester.pumpAndSettle();

    expect(storage.isElumiDevice, isFalse);
  });

  testWidgets('저장이 실패해도 화면이 멈추지 않는다', (tester) async {
    storage = _FailingRoleStorage();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('보호자예요'));
    await tester.pumpAndSettle();

    // 다음에 다시 물으면 될 뿐, 여기서 멈춰 세우지 않는다
    expect(find.text('이름 화면'), findsOneWidget);
  });
}

/// 역할 저장만 실패하는 저장소. 저장소 오류로 화면이 죽지 않는지 본다.
class _FailingRoleStorage extends InMemoryStorage {
  @override
  Future<void> setSelectedRole(String v) async =>
      throw Exception('저장소 오류');
}

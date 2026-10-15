import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/auth/presentation/role_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

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
          // 실제 NameScreen도 canPop이면 뒤로가기를 그린다. 대역도 같게 둔다.
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('이름 화면'),
                if (context.canPop())
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('이름에서 뒤로'),
                  ),
              ],
            ),
          ),
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

  // 전에는 카드를 누르면 바로 넘어갔다. 한 번 고르면 온보딩 경로가 갈리는
  // 화면이라, 잘못 눌렀을 때 되돌릴 여지를 둔다 (이슈 #229).
  testWidgets('보호자를 고르면 역할이 저장된다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('보호자가 사용해요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();

    expect(storage.selectedRole, AppRole.guardian.storageValue);
  });

  testWidgets('잘못 골라도 갇히지 않는다 — 연결 화면에서 되돌아온다 (이슈 #212)',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('이룸이가 사용해요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    // go로 갈아끼웠다면 스택이 없어 pop이 실패하고 연결 화면에 그대로 남는다
    // (이슈 #194와 같은 함정). push로 얹었기에 돌아올 수 있다.
    expect(find.text('보호자가 사용해요'), findsOneWidget);
  });

  testWidgets('저장이 실패해도 화면이 멈추지 않는다', (tester) async {
    storage = _FailingRoleStorage();
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('보호자가 사용해요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
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

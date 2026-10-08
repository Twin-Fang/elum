import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/guardian/presentation/pin_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/pin_setup_auth.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 설정 → 비밀암호 변경하기 (#437). 시안이 없어 온보딩 비밀번호 화면 부품을 쓴다 (#438).
///
/// 흐름: 지금 암호 확인 → 새 암호 → 한번 더 → 저장.
void main() {
  useFigmaViewport();

  late InMemoryStorage storage;

  Widget wrap({String? pin = '1234', LocalStorage? override}) {
    storage = InMemoryStorage(onboardingCompleted: true, pin: pin);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: Routes.login, builder: (_, _) => const Scaffold(body: Text('로그인'))),
        GoRoute(
          path: '/settings',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.push(Routes.guardianPinChange),
                child: const Text('설정 화면'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.guardianPinChange,
          builder: (context, state) => const PinChangeScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(override ?? storage), authRepositoryProvider.overrideWithValue(PinSetupAuth(allowed: false))],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  Future<void> open(WidgetTester tester, {String? pin = '1234', LocalStorage? override}) async {
    await tester.pumpWidget(wrap(pin: pin, override: override));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정 화면'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.pumpAndSettle();
  }

  testWidgets('지금 암호부터 묻는다', (tester) async {
    await open(tester);
    expect(find.text('지금 비밀암호를\n입력해주세요'), findsOneWidget);
    expect(find.byType(ElumButton), findsNothing);
  });

  testWidgets('지금 암호가 틀리면 넘어가지 않고 다시 묻는다 — 경고 팝업 없이', (tester) async {
    await open(tester);
    await enterPin(tester, '9999');

    expect(find.text('지금 비밀암호를\n입력해주세요'), findsOneWidget);
    expect(find.text('암호가 달라요. 다시 입력해주세요'), findsOneWidget);
    expect(find.byType(ElumDialogCard<void>), findsNothing);
  });

  testWidgets('끝까지 맞게 넣으면 새 암호로 저장하고 설정으로 돌아간다', (tester) async {
    await open(tester);
    await enterPin(tester, '1234');
    expect(find.text('새 비밀암호를\n입력해주세요'), findsOneWidget);

    await enterPin(tester, '5678');
    expect(find.text('비밀암호를 한번 더\n입력해주세요'), findsOneWidget);

    await enterPin(tester, '5678');
    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();

    expect(await storage.verifyPin('5678'), isTrue);
    expect(find.text('설정 화면'), findsOneWidget);
    expect(find.text('비밀암호를 바꿨어요'), findsOneWidget);
  });

  testWidgets('한번 더가 다르면 한번 더만 다시 받고 새 암호는 살린다', (tester) async {
    await open(tester);
    await enterPin(tester, '1234');
    await enterPin(tester, '5678');
    await enterPin(tester, '0000');

    expect(find.text('비밀암호를 한번 더\n입력해주세요'), findsOneWidget);
    expect(find.text('암호가 달라요. 다시 입력해주세요'), findsOneWidget);
    expect(find.byType(ElumButton), findsNothing);

    await enterPin(tester, '5678');
    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();
    expect(await storage.verifyPin('5678'), isTrue);
  });

  testWidgets('확정 전에 나가면 암호는 그대로다', (tester) async {
    await open(tester);
    await enterPin(tester, '1234');
    await enterPin(tester, '5678');

    await tester.tap(find.bySemanticsLabel('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(await storage.verifyPin('1234'), isTrue);
  });

  testWidgets('암호가 없던 휴대폰은 보호자 재로그인을 요구한다', (tester) async {
    await open(tester, pin: null);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('저장이 안 됐으면 실패 팝업을 띄우고 화면에 남는다', (tester) async {
    await open(tester, override: _BrokenPinStorage());
    await enterPin(tester, '1234');
    await enterPin(tester, '5678');
    await enterPin(tester, '5678');
    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();

    expect(find.byType(ElumDialogCard<void>), findsOneWidget);
    expect(find.text('E-PIN'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('설정 화면'), findsNothing);
  });
}

/// 보안 저장소 쓰기 오류를 호출부에 전달한다.
class _BrokenPinStorage extends InMemoryStorage {
  _BrokenPinStorage() : super(onboardingCompleted: true, pin: '1234');

  @override
  Future<void> setPin(String v) async => throw StateError('쓰기 실패');
}

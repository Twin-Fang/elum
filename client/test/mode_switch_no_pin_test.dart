import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:elum/features/guardian/presentation/pin_change_screen.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 저장된 암호가 없는 휴대폰에서 아무 숫자로 보호자 화면이 열리던 문제 (#355).
///
/// 암호가 없는 휴대폰은 두 경로로 생긴다 — 연결 암호로 붙은 이룸이 휴대폰, 그리고
/// 기존 계정으로 다시 로그인해 암호 만들기를 건너뛴 보호자 휴대폰.
void main() {
  useFigmaViewport();

  late InMemoryStorage storage;

  Widget wrap({
    String? pin,
    bool isElumi = false,
    LocalStorage? override,
    ModeSwitchTarget target = ModeSwitchTarget.guardian,
  }) {
    storage = InMemoryStorage(onboardingCompleted: true, pin: pin);
    if (isElumi) storage.setElumiDevice(true);
    final router = GoRouter(
      initialLocation: Routes.child,
      routes: [
        GoRoute(
          path: Routes.child,
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    context.push('${Routes.modeSwitch}?to=${target.name}'),
                child: const Text('이룸이 홈'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.modeSwitch,
          builder: (context, state) => ModeSwitchScreen(
            target: ModeSwitchTarget.fromName(state.uri.queryParameters['to']),
          ),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
        GoRoute(
          path: Routes.guardianPinChange,
          builder: (context, state) => PinChangeScreen(
            createOnly: state.uri.queryParameters['from'] == 'mode-switch',
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(override ?? storage)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  /// 이룸이 홈의 톱니를 누른 것처럼 암호 화면으로 들어간다.
  Future<void> open(
    WidgetTester tester, {
    String? pin,
    bool isElumi = false,
    LocalStorage? override,
    ModeSwitchTarget target = ModeSwitchTarget.guardian,
  }) async {
    await tester.pumpWidget(
      wrap(pin: pin, isElumi: isElumi, override: override, target: target),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('이룸이 홈'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.pumpAndSettle();
  }

  group('보호자 휴대폰 — 암호가 없다', () {
    testWidgets('아무 숫자를 넣어도 보호자 화면이 열리지 않고 암호 만들기로 간다', (tester) async {
      await open(tester);

      // 비교할 암호가 없으니 입력창 대신 암호를 만드는 화면이 떠야 한다
      expect(find.text('보호자님만 아는\n비밀암호를 만들어주세요'), findsOneWidget);

      await enterPin(tester, '0000');

      expect(find.text('보호자 홈'), findsNothing, reason: '암호 없이 보호자 홈에 도달했다');
      expect(await storage.getPin(), isNull, reason: '확정 전에 저장되면 안 된다');
    });

    testWidgets('암호를 만들어 저장하면 그 암호로 보호자 화면이 열린다', (tester) async {
      await open(tester);
      await enterPin(tester, '1111');
      expect(find.text('암호를 한번 더\n입력해주세요'), findsOneWidget);
      await enterPin(tester, '1111');
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
      expect(await storage.getPin(), '1111');
      expect(find.text('비밀암호를 만들었어요'), findsOneWidget);
    });

    testWidgets('저장된 암호가 빈 문자열이어도 없는 것으로 본다', (tester) async {
      await open(tester, pin: '');
      expect(find.text('보호자님만 아는\n비밀암호를 만들어주세요'), findsOneWidget);

      await enterPin(tester, '0000');
      expect(find.text('보호자 홈'), findsNothing);
    });

    testWidgets('만들다가 뒤로 가면 이룸이 홈으로 돌아오고 암호는 생기지 않는다', (tester) async {
      await open(tester);
      await enterPin(tester, '1111');
      await tester.tap(find.bySemanticsLabel(ElumScaffold.backLabel));
      await tester.pumpAndSettle();

      expect(find.text('이룸이 홈'), findsOneWidget);
      expect(find.text('보호자 홈'), findsNothing);
      expect(await storage.getPin(), isNull);
    });
  });

  group('이룸이 휴대폰 — 암호가 없다', () {
    testWidgets('보호자 화면으로 들어가지 못하고 안내만 보인다', (tester) async {
      await open(tester, isElumi: true);

      expect(find.text('보호자 휴대폰에서\n열어 주세요'), findsOneWidget);
      // 입력창이 없으니 숫자를 넣어 볼 수도 없다
      expect(find.byType(TextField), findsNothing);
      expect(find.text('보호자 홈'), findsNothing);
      // 이룸이가 암호를 만들 수 있는 화면으로도 보내지 않는다
      expect(find.text('보호자님만 아는\n비밀암호를 만들어주세요'), findsNothing);
      expect(await storage.getPin(), isNull);
    });

    testWidgets('돌아가기를 누르면 이룸이 홈으로 돌아온다', (tester) async {
      await open(tester, isElumi: true);
      await tester.tap(find.text('돌아가기'));
      await tester.pumpAndSettle();

      expect(find.text('이룸이 홈'), findsOneWidget);
    });

    testWidgets('암호가 남아 있으면 종전처럼 비교한다', (tester) async {
      await open(tester, pin: '1234', isElumi: true);

      await enterPin(tester, '0000');
      expect(find.text('보호자 홈'), findsNothing);
      expect(find.text('암호가 달라요. 다시 넣어주세요'), findsOneWidget);

      await enterPin(tester, '1234');
      expect(find.text('보호자 홈'), findsOneWidget);
    });
  });

  group('실패 경로', () {
    testWidgets('암호를 읽지 못하면 통과시키지 않고 에러 코드를 보여준다', (tester) async {
      await open(tester, override: _UnreadablePinStorage());

      expect(find.byType(ElumDialogCard<void>), findsOneWidget);
      expect(find.text('E-PIN-READ'), findsOneWidget);
      expect(find.text('보호자 홈'), findsNothing);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      // 팝업을 닫으면 이룸이 홈으로 돌아온다 — 빈 화면에 남지 않는다
      expect(find.text('이룸이 홈'), findsOneWidget);
    });
  });

  group('보호자 → 이룸이 방향', () {
    testWidgets('이 방향은 지키는 대상이 아니라 종전처럼 암호 없이 지나간다', (tester) async {
      // 이룸이 화면은 막을 이유가 없다. 이 변경은 보호자 화면 입구만 닫는다.
      await tester.pumpWidget(wrap(target: ModeSwitchTarget.child));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이룸이 홈'));
      await tester.pumpAndSettle();

      expect(find.text('암호를 입력하면 이룸이 화면으로 바뀌어요'), findsOneWidget);
    });
  });
}

/// 암호 읽기에서 예외가 나는 저장소.
class _UnreadablePinStorage extends InMemoryStorage {
  _UnreadablePinStorage() : super(onboardingCompleted: true);

  @override
  Future<String?> getPin() async => throw StateError('읽기 실패');
}

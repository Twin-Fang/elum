import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/presentation/invite_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';
import 'helpers/test_storage.dart';

/// 초대 코드 만들기 — 연결된 보호자가 함께할 보호자를 부른다 (#362 · 서버 #361).
///
/// **연결 암호(이룸이 휴대폰)와 다른 화면이다.** 말도 다르게 쓴다 — 여기는 `초대 코드`,
/// 이룸이 휴대폰은 `연결 암호`. 1초 타이머가 돌아 `pumpAndSettle()` 을 쓰지 않는다.
void main() {
  useFigmaViewport();

  late FakeProfileRepository repo;

  setUp(() => repo = FakeProfileRepository());

  Widget wrap({String? selected = 'p-a'}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('이전 화면'))),
        GoRoute(path: '/invite', builder: (_, _) => const InviteCodeScreen()),
      ],
    );
    return ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        memberProvider.overrideWith(
          (ref) async => selected == null
              ? memberWith(const [])
              : memberWith([kProfileA, kProfileB]),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, {String? selected = 'p-a'}) async {
    await tester.pumpWidget(wrap(selected: selected));
    await tester.pump();
    final ctx = tester.element(find.text('이전 화면'));
    GoRouter.of(ctx).push('/invite');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('고른 이룸이의 초대 코드를 만들어 여섯 글자를 낱개로 보여 준다', (tester) async {
    await open(tester);

    expect(repo.calls, contains('issue:p-a'));
    for (final ch in 'A7K3M9'.split('')) {
      expect(find.text(ch), findsOneWidget);
    }
  });

  testWidgets('남은 시간을 MM:SS 로 보여 주고 이룸이 이름과 초대 코드라는 말을 쓴다', (tester) async {
    await open(tester);

    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
    // 이룸이 휴대폰의 연결 암호와 말을 섞지 않는다
    expect(find.textContaining('연결 암호'), findsNothing);
    expect(find.textContaining('초대 코드'), findsWidgets);
    expect(find.textContaining('하늘이'), findsWidgets);
  });

  testWidgets('다시 만들면 새로 발급하고 이전 코드는 쓸 수 없다고 알린다 (E9)', (tester) async {
    await open(tester);
    expect(find.textContaining('이전 코드'), findsOneWidget);

    await tester.tap(find.text('초대 코드 다시 만들기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.calls.where((c) => c.startsWith('issue')).length, 2);
  });

  testWidgets('만료되면 코드를 흐리게 하고 만료됐다고 말한다', (tester) async {
    repo.issueResult = Attempt.ok(
      IssuedLinkCode(code: 'A7K3M9', expiresAt: DateTime.now().subtract(const Duration(seconds: 1))),
    );
    await open(tester);

    expect(find.text('초대 코드가 만료됐어요'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsNothing);
    // 새로 만드는 길은 남는다
    expect(find.text('초대 코드 다시 만들기'), findsOneWidget);
  });

  group('실패해도 화면이 산다', () {
    testWidgets('인터넷이 없으면 안내와 에러 코드와 다시 시도를 보여 준다 (E47)', (tester) async {
      repo.issueResult = const Attempt.failed(AppFailure(fault: NetworkFault.offline));
      await open(tester);

      expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
      expect(find.textContaining('인터넷'), findsWidgets);

      repo.issueResult = Attempt.ok(
        IssuedLinkCode.fromNow(code: 'B2C3D4', expiresInSeconds: 600),
      );
      await tester.tap(find.textContaining('다시 시도'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('시도 한도(429)는 서버 문구와 코드를 그대로 보여 준다', (tester) async {
      repo.issueResult = const Attempt.failed(
        AppFailure(
          fault: NetworkFault.none,
          server: ServerError(
            code: ServerErrorCode.profileInviteTooManyAttempts,
            message: '여러 번 잘못 입력했어요. 잠시 뒤에 다시 하거나 새 코드를 받아주세요.',
            statusCode: 429,
          ),
        ),
      );
      await open(tester);

      expect(find.textContaining('여러 번 잘못 입력했어요'), findsOneWidget);
      expect(find.text('PROFILE_INVITE_TOO_MANY_ATTEMPTS'), findsOneWidget);
    });

    testWidgets('이룸이 휴대폰·연결 안 된 이룸이(403)는 다시 시도 버튼 없이 이유만 보여 준다', (tester) async {
      repo.issueResult = const Attempt.failed(
        AppFailure(
          fault: NetworkFault.none,
          server: ServerError(
            code: ServerErrorCode.profileAccessDenied,
            message: '이 이룸이의 정보를 볼 수 없어요.',
            statusCode: 403,
          ),
        ),
      );
      await open(tester);

      expect(find.text('이 이룸이의 정보를 볼 수 없어요.'), findsOneWidget);
      expect(find.text('PROFILE_ACCESS_DENIED'), findsOneWidget);
      // 다시 해도 같은 이유로 막힌다
      expect(find.textContaining('다시 시도'), findsNothing);
    });

    testWidgets('연결된 이룸이가 없으면 발급을 부르지 않고 알린다', (tester) async {
      await open(tester, selected: null);

      expect(repo.calls, isEmpty);
      expect(find.textContaining('E-INV-NONE'), findsOneWidget);
    });
  });
}

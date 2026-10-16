import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/profile/application/invite_sharer.dart';
import 'package:elum/features/profile/domain/invite_link.dart';
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
import 'package:elum/features/member/application/member_providers.dart';

/// 초대 코드 만들기 — 연결된 보호자가 함께할 보호자를 부른다 (#362 · 서버 #361).
///
/// **연결 암호(이룸이 휴대폰)와 다른 화면이다.** 말도 다르게 쓴다 — 여기는 `초대 코드`,
/// 이룸이 휴대폰은 `연결 암호`. 1초 타이머가 돌아 `pumpAndSettle()` 을 쓰지 않는다.
void main() {
  useFigmaViewport();

  late FakeProfileRepository repo;

  /// 공유 시트에 실린 문구. 진짜 시트는 OS 가 띄우므로 가짜로 바꿔 끼운다.
  late List<String> shared;
  Object? shareError;

  setUp(() {
    repo = FakeProfileRepository();
    shared = [];
    shareError = null;
  });

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
        inviteSharerProvider.overrideWithValue((text) async {
          if (shareError != null) throw shareError!;
          shared.add(text);
        }),
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




  testWidgets('코드 아래에 복사하기와 바뀌는 시간이 있고 다시 만들기 칩·안내 문구는 없다', (tester) async {
    await open(tester);

    expect(find.text('코드 복사하기'), findsOneWidget);
    expect(find.text('뒤에 코드가 바껴요'), findsOneWidget);
    expect(find.text('코드 다시 만들기'), findsNothing);
    expect(find.textContaining('이전 코드'), findsNothing);
  });

  // 흐린 코드와 `만료됐어요`를 보이면 보호자가 직접 다시 만들어야 한다
  testWidgets('시간이 다 되면 만료 문구 없이 새 코드로 바뀐다 (E9: 앞 코드는 서버가 폐기)', (tester) async {
    repo.issueResult = Attempt.ok(
      IssuedLinkCode.fromNow(code: 'A7K3M9', expiresInSeconds: 1),
    );
    await open(tester);
    expect(repo.calls.where((c) => c.startsWith('issue')).length, 1);

    repo.issueResult = Attempt.ok(
      IssuedLinkCode.fromNow(code: 'B2C3D4', expiresInSeconds: 600),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.calls.where((c) => c.startsWith('issue')).length, 2);
    expect(find.textContaining('만료'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('코드 다시 만들기'), findsNothing);
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

  });

  group('링크로 보내기 (#365)', () {
    testWidgets('공유 시트에 링크와 10분 안내를 담아 보낸다', (tester) async {
      await open(tester);

      await tester.tap(find.text('링크로 보내기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(shared.length, 1);
      expect(shared.single, contains(InviteLink.shareUrl('A7K3M9')));
      expect(shared.single, contains('10분'));
      expect(shared.single, contains('초대 코드'));
      expect(shared.single, isNot(contains('연결 암호')));
    });


    testWidgets('만료되면 버튼을 눌러도 보내지 않는다 — 못 쓰는 코드를 퍼뜨리지 않는다', (tester) async {
      repo.issueResult = Attempt.ok(
        IssuedLinkCode(code: 'A7K3M9', expiresAt: DateTime.now().subtract(const Duration(seconds: 1))),
      );
      await open(tester);

      await tester.tap(find.text('링크로 보내기'), warnIfMissed: false);
      await tester.pump();

      expect(shared, isEmpty);
    });




  });
}

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/link_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 연결 암호 만들기 — 보호자 휴대폰 (Figma 732:5334 · 732:5850 · 이슈 #232).
///
/// **1초 타이머가 계속 돌기 때문에 `pumpAndSettle()`을 쓰지 않는다.** 정착할
/// 프레임이 없어 타임아웃한다. 필요한 만큼만 `pump()`한다.
void main() {
  useFigmaViewport();

  late _FakeLink repo;

  setUp(() => repo = _FakeLink());

  Widget wrap({String nickname = '', double textScale = 1}) {
    final router = GoRouter(
      initialLocation: Routes.linkCode,
      routes: [
        GoRoute(
          path: Routes.linkCode,
          builder: (context, state) =>
              const LinkCodeScreen(fromOnboarding: true),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        deviceLinkRepositoryProvider.overrideWithValue(repo),
        testStorageOverride(nickname: nickname),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
  }

  /// 발급이 끝나 암호가 화면에 나올 때까지만 돌린다.
  Future<void> settleIssue(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 남은 시간은 실제 시계(DateTime.now)로 재므로 실제로 기다린 뒤 1초 타이머를 한 번 돌린다.
  Future<void> expireFirstCode(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  bool ctaEnabled(WidgetTester tester) =>
      tester.widget<ElumButton>(find.widgetWithText(ElumButton, '시작하기')).onPressed != null;

  group('대기 상태 (732:5334)', () {
    testWidgets('남은 시간을 MM:SS로 보여준다 (이슈 #232)', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      // 전에는 `10분 동안 쓸 수 있어요`였다. 시안이 초까지 센다.
      expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
      expect(find.textContaining('분 동안'), findsNothing);
    });

  });


  group('코드 아래 (1532:6798)', () {
    testWidgets('링크로 보내기와 코드 복사하기가 있고 다시 만들기 칩은 없다', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      expect(find.text('링크로 보내기'), findsOneWidget);
      expect(find.text('코드 복사하기'), findsOneWidget);
      expect(find.text('코드 다시 만들기'), findsNothing);
      expect(find.text('뒤에 코드가 바껴요'), findsOneWidget);
    });

    // 코드가 만료돼도 새 코드를 받는 길이 없으면 이 화면에서 멈춘다 (다시 만들기 칩이 시안에서 빠졌다)
    testWidgets('만료되면 새 코드를 자동으로 받아 타이머를 다시 돌린다', (tester) async {
      repo.firstExpiresInSeconds = 1;
      await tester.pumpWidget(wrap());
      await settleIssue(tester);
      expect(repo.issueCount, 1);

      await expireFirstCode(tester);

      expect(repo.issueCount, 2);
      expect(find.text('코드 복사하기'), findsOneWidget);
      expect(find.textContaining('09:5'), findsOneWidget);
    });

    testWidgets('자동 갱신에 실패하면 다시 만들기 칩이 나온다', (tester) async {
      repo.firstExpiresInSeconds = 1;
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      repo.isIssueFailing = true;
      await expireFirstCode(tester);

      expect(find.text('코드 다시 만들기'), findsOneWidget);
      expect(find.text('코드 복사하기'), findsNothing);
      // 실패를 삼키지 않는다: 에러 코드가 보인다
      expect(find.textContaining('E-LINK-NEW'), findsOneWidget);
    });
  });

  group('연결됨 (732:5850)', () {
    testWidgets('연결되면 타이머와 복사하기가 사라지고 시작하기가 열린다', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      repo.linked = true;
      // 폴링 주기 3초
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      // 성공 팝업이 먼저 뜬다
      expect(find.text('휴대폰 연결에 성공했어요!'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 더 기다릴 이유가 없으므로 타이머도 다시 만들기도 치운다
      expect(find.text('코드 다시 만들기'), findsNothing);
      expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsNothing);
      expect(ctaEnabled(tester), isTrue);
    });
  });

  // #363 — 이미 연결된 상태에서 이 화면을 열면 예전 연결을 방금 성공한 것처럼 알렸다.
  // 화면이 3초마다 상태를 물어 `hasDevice` 만 보았기 때문이다. 이 화면이 열린 뒤 **새로 붙은** 휴대폰만 알린다.
  group('이미 연결된 휴대폰이 있을 때 (#363)', () {
    testWidgets('예전 연결을 방금 성공한 것처럼 알리지 않는다', (tester) async {
      repo.deviceIds.add('l-old');
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('휴대폰 연결에 성공했어요!'), findsNothing);
      // 암호는 그대로 보이고 기다린다 — 타이머도 살아 있다
      expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
    });

  });

  // #393 S6 — 보상 화면(#380 실기기 A)과 같은 구조였다. 자리를 글자 높이 16 으로
  // 못 박고 OverflowBox 로 덮어, 글꼴을 키우면 글자가 16 상자에 갇혀 아래가 잘린다.
  // 넘친 것이 아니라 잘린 것이라 넘침 검사로는 못 잡는다 — 그려진 높이를 잰다.
}

class _FakeLink extends DeviceLinkRepository {
  _FakeLink()
      : super(
          dio: Dio(),
          tokens: InMemoryTokenStore(),
          storage: InMemoryStorage(),
        );

  bool linked = false;

  /// 이 화면을 열기 전부터 붙어 있던 휴대폰들 (#363).
  final deviceIds = <String>[];

  /// 첫 발급만 짧게 만료시킨다 (자동 갱신 시험용). 이후는 600초.
  int? firstExpiresInSeconds;
  int issueCount = 0;

  /// 발급이 실패한다 (400, 서버 문구 없음)
  bool isIssueFailing = false;

  @override
  Future<Attempt<IssuedLinkCode>> issue() async {
    issueCount++;
    if (isIssueFailing) {
      return Attempt.failed(
        const AppFailure(fault: NetworkFault.none),
      );
    }
    final seconds = issueCount == 1 ? (firstExpiresInSeconds ?? 600) : 600;
    return Attempt.ok(
      IssuedLinkCode.fromNow(code: '5NJ280', expiresInSeconds: seconds),
    );
  }

  @override
  Future<Attempt<LinkStatus>> statusResult() async =>
      Attempt.ok(LinkStatus(
        devices: [
          for (final id in [...deviceIds, if (linked) 'l1'])
            LinkedDevice(linkId: id, linkedAt: DateTime(2026, 9, 18)),
        ],
      ));
}

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/link/presentation/link_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

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

  bool ctaEnabled(WidgetTester tester) =>
      tester.widget<ElumButton>(find.byType(ElumButton)).onPressed != null;

  group('대기 상태 (732:5334)', () {
    testWidgets('암호 여섯 글자가 낱개로 놓인다', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      // 낱개로 놓아야 3-3 묶음의 가운데 간격을 벌릴 수 있다.
      for (final ch in '5NJ280'.split('')) {
        expect(find.text(ch), findsOneWidget);
      }
    });

    testWidgets('남은 시간을 MM:SS로 보여준다 (이슈 #232)', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      // 전에는 `10분 동안 쓸 수 있어요`였다. 시안이 초까지 센다.
      expect(find.textContaining(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
      expect(find.textContaining('분 동안'), findsNothing);
    });

    testWidgets('코드 다시 만들기 칩이 있다', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      expect(find.text('코드 다시 만들기'), findsOneWidget);
    });

    testWidgets('연결되기 전에는 시작하기를 누를 수 없다', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      expect(find.text('시작하기'), findsOneWidget);
      expect(ctaEnabled(tester), isFalse);
    });

    testWidgets('암호 복사는 없어졌다 (이슈 #232)', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      // 보호자가 불러주고 이룸이가 받아적는 구조라 시안에서 빠졌다.
      expect(find.text('암호 복사'), findsNothing);
    });
  });

  group('이룸이 이름', () {
    testWidgets('이름을 제목과 설명에 함께 넣는다', (tester) async {
      await tester.pumpWidget(wrap(nickname: '하늘이'));
      await settleIssue(tester);

      expect(find.textContaining('하늘이의 휴대폰을'), findsOneWidget);
      expect(find.textContaining('하늘이의 휴대폰에서'), findsOneWidget);
    });

    testWidgets('이름이 비면 이룸이로 대신한다', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      // 설정에서 바로 들어오면 이름이 없을 수 있다. `의`가 붙은 빈 자리가
      // 남으면 문장이 깨진다.
      expect(find.textContaining('이룸이의 휴대폰을'), findsOneWidget);
    });

    testWidgets('이름이 길어도 제목이 잘리지 않는다', (tester) async {
      await tester.pumpWidget(wrap(nickname: '김민준서연하늘'));
      await settleIssue(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('김민준서연하늘의 휴대폰을'), findsOneWidget);
    });
  });

  group('연결됨 (732:5850)', () {
    testWidgets('연결되면 타이머와 다시 만들기가 사라지고 시작하기가 열린다', (tester) async {
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

  // #393 S6 — 보상 화면(#380 실기기 A)과 같은 구조였다. 자리를 글자 높이 16 으로
  // 못 박고 OverflowBox 로 덮어, 글꼴을 키우면 글자가 16 상자에 갇혀 아래가 잘린다.
  // 넘친 것이 아니라 잘린 것이라 넘침 검사로는 못 잡는다 — 그려진 높이를 잰다.
  group('큰 글꼴에서 나중에 할게요가 잘리지 않는다 (#393 S6)', () {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('글꼴 $scale', (tester) async {
        await tester.pumpWidget(wrap(textScale: scale));
        await settleIssue(tester);

        final label = find.text('나중에 할게요');
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(needed - 0.5),
          reason: '글자 높이 $needed 인데 ${paragraph.size.height} 만 그려진다',
        );
        // 글자 위를 덮는 조상 상자가 글자보다 작으면 누름·그리기가 거기서 끊긴다.
        final rect = tester.getRect(label);
        final holder = tester.getRect(
          find.ancestor(of: label, matching: find.byType(Center)).first,
        );
        expect(holder.top, lessThanOrEqualTo(rect.top + 0.5));
        expect(holder.bottom, greaterThanOrEqualTo(rect.bottom - 0.5));
        expect(rect.bottom, lessThanOrEqualTo(852));
      });
    }

    testWidgets('글꼴 1.0 에서는 시안 자리 그대로다 — 시작하기와 사이가 변하지 않는다', (tester) async {
      await tester.pumpWidget(wrap());
      await settleIssue(tester);

      // 시안 732:5334 — 나중에 할게요 y=765, 높이 16
      final rect = tester.getRect(find.text('나중에 할게요'));
      expect(rect.height, moreOrLessEquals(16, epsilon: 1));
    });
  });
}

class _FakeLink extends DeviceLinkRepository {
  _FakeLink()
      : super(
          dio: Dio(),
          tokens: InMemoryTokenStore(),
          storage: InMemoryStorage(),
        );

  bool linked = false;

  @override
  Future<Attempt<IssuedLinkCode>> issue() async => Attempt.ok(
        IssuedLinkCode.fromNow(code: '5NJ280', expiresInSeconds: 600),
      );

  @override
  Future<LinkStatus> status() async => LinkStatus(
        devices: linked
            ? [LinkedDevice(linkId: 'l1', linkedAt: DateTime(2026, 9, 18))]
            : const [],
      );
}

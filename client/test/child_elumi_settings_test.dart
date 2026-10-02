import 'package:dio/dio.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/character_badge.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/auth/presentation/consent_document_list_screen.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/link/presentation/elumi_settings_screen.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';

/// 이룸이 휴대폰의 상단 바와 설정 페이지 (이슈 #363 · #198 19번 · #488).
///
/// 이룸이 휴대폰은 보호자 화면에 갈 곳이 없다. 톱니가 설정 **페이지**를 열고(보호자 설정과 같다 — 바텀시트가 아니다, #488), 페이지의 `로그아웃`·`회원탈퇴`는
/// **이 휴대폰의 연결만** 끊는다. 되돌릴 수 없는 동작이라 성공·실패·이미 끊김을 모두 밟는다 —
/// 서버가 끊기지 않았는데 로컬만 비우면 보호자 설정에는 계속 `연결됨`이 남는다.
void main() {
  useFigmaViewport();

  late FakeAdapter adapter;
  late Map<String, Object?> routes;
  late InMemoryStorage storage;
  late InMemoryTokenStore tokens;

  setUp(() async {
    routes = {'DELETE /api/device-links/current': const <String, Object?>{}};
    adapter = FakeAdapter(routes);
    storage = InMemoryStorage(elumiDevice: true, onboardingCompleted: true);
    await storage.setNickname('하늘이');
    await storage.setCharacter('FOX');
    await storage.setCachedTodayRoutinesJson('[{"id":"r1"}]');
    tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
  });

  Widget wrap({bool elumi = true}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: Routes.child,
      routes: [
        GoRoute(
          path: Routes.child,
          builder: (context, state) => const ChildHomeScreen(),
        ),
        GoRoute(
          path: Routes.childSettings,
          builder: (context, state) => const ElumiSettingsScreen(),
        ),
        GoRoute(
          path: Routes.childStars,
          builder: (context, state) => const Scaffold(body: Text('별 화면')),
        ),
        GoRoute(
          path: Routes.modeSwitch,
          builder: (context, state) => const Scaffold(body: Text('비밀암호 화면')),
        ),
        GoRoute(
          path: Routes.roleSelect,
          builder: (context, state) => const Scaffold(body: Text('역할 선택')),
        ),
        GoRoute(
          path: Routes.linkEnter,
          builder: (context, state) => const Scaffold(body: Text('연결 암호 넣기')),
        ),
      ],
    );
    if (!elumi) storage = InMemoryStorage(onboardingCompleted: true);
    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        tokenStoreProvider.overrideWithValue(tokens),
        localStorageProvider.overrideWithValue(storage),
        // 실서버를 타지 않는다
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        memberProvider.overrideWith(
          (ref) async => const Member(totalStars: 12),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, {bool elumi = true}) async {
    await tester.pumpWidget(wrap(elumi: elumi));
    await tester.pumpAndSettle();
  }

  Finder labeled(String label) => find.bySemanticsLabel(label);

  /// 설정 톱니를 눌러 설정 페이지로 간다 (#488 — 바텀시트가 아니라 페이지).
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(labeled('설정 열기'));
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(ElumDialogCard<bool>),
    matching: find.text(label),
  );

  group('상단 바', () {
    testWidgets('이룸이 휴대폰 — 보호자 화면으로 가는 버튼은 없고 설정 톱니가 별 오른쪽에 있다 (시안 1197:6774)', (
      tester,
    ) async {
      await pump(tester);

      expect(labeled('보호자 화면으로 가기'), findsNothing, reason: '갈 곳이 없다');
      expect(labeled('설정 열기'), findsOneWidget);

      final gear = tester.getCenter(labeled('설정 열기'));
      final star = tester.getCenter(labeled('별 12개 모았어요'));
      expect(gear.dx, greaterThan(star.dx), reason: '시안 1197:6774: 별 오른쪽');
      // 톱니 그림 24×24 가 x345~369 에 선다 → 가운데 x357
      expect(gear.dx, closeTo(357, 0.6));
    });

    testWidgets('보호자 휴대폰 — 톱니가 아니라 캐릭터 배지다 (시안 425:4392)', (tester) async {
      await pump(tester, elumi: false);

      expect(labeled('설정 열기'), findsNothing, reason: '이 휴대폰에는 설정이 없다');
      expect(
        find.byType(CharacterBadge),
        findsOneWidget,
        reason: '캐릭터 배지가 보호자 화면으로 가는 입구다',
      );

      // 시안 425:4392 — 별 x247 y74 50×48 · 배지 x313 y70 56×56
      final star = tester.getRect(
        find.descendant(
          of: labeled('별 12개 모았어요'),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(star.left, closeTo(247, 0.6));
      final badge = tester.getRect(find.byType(CharacterBadge));
      expect(badge.left, closeTo(313, 0.6));
      expect(badge.size, const Size(56, 56));
      // 이 하네스는 안전영역(59)이 없어 절대 y 는 못 잰다. 시안의 상대 차이로 맞춘다:
      // 별 윗변 74 − 배지 윗변 70 = 4, 배지 윗변은 안전영역 아래 11.
      expect(star.top - badge.top, closeTo(4, 0.6));
      expect(badge.top, closeTo(11, 0.6));

      await tester.tap(labeled('보호자 화면으로 가기'));
      await tester.pumpAndSettle();
      expect(find.text('비밀암호 화면'), findsOneWidget);
    });

    testWidgets('이룸이 휴대폰 — 누를 자리끼리 8 이상 떨어진다 (오탭 방지)', (tester) async {
      await pump(tester);

      final gear = tester.getRect(labeled('설정 열기'));
      final star = tester.getRect(labeled('별 12개 모았어요'));
      // 아동 화면은 터치 타겟을 넉넉히 잡는다 (client/CLAUDE.md — 최소 48 이상)
      expect(gear.width, greaterThanOrEqualTo(48));
      expect(gear.height, greaterThanOrEqualTo(48));
      expect(gear.left - star.right, greaterThanOrEqualTo(8));
    });
  });

  group('설정 페이지', () {
    testWidgets('톱니를 누르면 바텀시트가 아니라 설정 페이지로 간다 (#488)', (tester) async {
      await pump(tester);
      await openSettings(tester);

      expect(find.byType(ElumiSettingsScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing, reason: '보호자 설정과 같은 페이지다');
      // 홈은 뒤로 밀려 보이지 않는다
      expect(find.byType(ChildHomeScreen), findsNothing);
    });

    testWidgets('뒤로가기를 누르면 이룸이 홈으로 돌아온다', (tester) async {
      await pump(tester);
      await openSettings(tester);

      await tester.tap(labeled('뒤로 가기'));
      await tester.pumpAndSettle();

      expect(find.byType(ElumiSettingsScreen), findsNothing);
      expect(find.byType(ChildHomeScreen), findsOneWidget);
    });

    testWidgets('항목은 넷뿐이다 — 약관 · 앱 정보 · 로그아웃 · 회원탈퇴. 일과를 만들거나 고치는 길은 없다', (
      tester,
    ) async {
      await pump(tester);
      await openSettings(tester);

      expect(find.text('설정'), findsOneWidget);
      expect(find.text('약관 및 개인정보처리방침'), findsOneWidget);
      expect(find.text('앱 정보'), findsOneWidget);
      expect(find.text('로그아웃'), findsOneWidget);
      expect(find.text('회원탈퇴'), findsOneWidget);
      // 보호자 설정의 항목은 하나도 따라오지 않는다
      for (final forbidden in [
        '일과 만들기',
        '비밀암호',
        '보호자 화면',
        '이룸이 휴대폰 연결하기',
        '임시저장',
      ]) {
        expect(find.textContaining(forbidden), findsNothing);
      }
    });

    testWidgets('약관 줄을 누르면 약관 목록 화면이 열린다', (tester) async {
      await pump(tester);
      await openSettings(tester);

      await tester.tap(find.text('약관 및 개인정보처리방침'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsentDocumentListScreen), findsOneWidget);
    });

    testWidgets('설정 시트는 암호를 묻지 않는다 — 비밀암호 화면으로 가지 않는다', (tester) async {
      await pump(tester);
      await openSettings(tester);

      expect(find.text('비밀암호 화면'), findsNothing);
    });
  });

  group('로그아웃 · 회원탈퇴 — 이 휴대폰의 연결만 끊는다', () {
    testWidgets('로그아웃: 확인 팝업에서 취소하면 아무 일도 없다', (tester) async {
      await pump(tester);
      await openSettings(tester);

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      expect(find.text('로그아웃 하실건가요?'), findsOneWidget);
      expect(find.textContaining('연결 암호를 받아야 해요'), findsOneWidget);

      await tester.tap(dialogButton('취소'));
      await tester.pumpAndSettle();

      expect(adapter.calls, isEmpty);
      expect(tokens.hasSession, isTrue);
      expect(find.text('로그아웃'), findsOneWidget, reason: '설정 페이지에 그대로 남는다');
    });

    testWidgets('로그아웃 확인: 서버가 끊긴 뒤 로컬을 비우고 연결 암호 넣기로 간다', (tester) async {
      await pump(tester);
      await openSettings(tester);

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(adapter.calls, ['DELETE /api/device-links/current']);
      expect(find.text('연결 암호 넣기'), findsOneWidget);
      expect(tokens.hasSession, isFalse);
      expect(storage.nickname, isNull);
      expect(storage.cachedTodayRoutinesJson, isNull);
      expect(
        storage.isElumiDevice,
        isTrue,
        reason: '여전히 이룸이 휴대폰 — 로그인 화면이 아니라 연결 화면으로 간다',
      );
      expect(
        storage.isElumiLinkLost,
        isFalse,
        reason: '스스로 끊은 것이라 `끊어졌어요`를 말하지 않는다',
      );
    });

    testWidgets('연결 화면에서 뒤로 가면 역할 선택이다 — 스택이 비지 않는다 (#212)', (tester) async {
      await pump(tester);
      await openSettings(tester);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      final router = GoRouter.of(tester.element(find.text('연결 암호 넣기')));
      expect(router.canPop(), isTrue);
    });

    testWidgets('회원탈퇴: 일과와 별이 보호자 휴대폰에 남는다고 말하고, 같은 연결 끊기를 한다', (tester) async {
      await pump(tester);
      await openSettings(tester);

      await tester.tap(find.text('회원탈퇴'));
      await tester.pumpAndSettle();
      expect(find.text('회원탈퇴 하실건가요?'), findsOneWidget);
      expect(find.textContaining('일과와 별은 보호자 휴대폰에'), findsOneWidget);
      expect(find.textContaining('이 휴대폰의 연결만 끊어져요'), findsOneWidget);

      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(adapter.calls, ['DELETE /api/device-links/current']);
      expect(find.text('연결 암호 넣기'), findsOneWidget);
    });

    testWidgets('끊은 뒤 메모리에 남은 이전 이룸이 정보도 비운다 — 다른 이룸이에게 붙어도 섞이지 않는다', (
      tester,
    ) async {
      await pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChildHomeScreen)),
      );
      expect(container.read(onboardingProvider).childNickname, '하늘이');

      await openSettings(tester);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(container.read(onboardingProvider).childNickname, isNot('하늘이'));
    });

    testWidgets('이미 끊겨 있으면(404) 실패로 보이지 않고 정리한 뒤 연결 화면으로 간다', (tester) async {
      routes['DELETE /api/device-links/current'] = const FakeHttpError(
        404,
        errorCode: 'DEVICE_LINK_NOT_CONNECTED',
      );
      await pump(tester);
      await openSettings(tester);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.text('연결 암호 넣기'), findsOneWidget);
      expect(tokens.hasSession, isFalse);
    });

    for (final (name, response, expected) in [
      ('서버 오류(500)', const FakeHttpError(500), 'E-LINK-OUT/500'),
      (
        '서버가 이유를 준 403',
        const FakeHttpError(
          403,
          errorCode: 'DEVICE_LINK_ONLY_FOR_ELUMI',
          errorMessage: '이룸이 휴대폰에서만 할 수 있어요.',
        ),
        'DEVICE_LINK_ONLY_FOR_ELUMI',
      ),
      ('인터넷 없음', const FakeOffline(), 'E-NET-OFFLINE'),
    ]) {
      testWidgets('$name: 머물고 에러 코드를 보여주며 아무것도 지우지 않는다', (tester) async {
        routes['DELETE /api/device-links/current'] = response;
        await pump(tester);
        await openSettings(tester);
        await tester.tap(find.text('회원탈퇴'));
        await tester.pumpAndSettle();
        await tester.tap(dialogButton('확인'));
        await tester.pumpAndSettle();

        expect(find.textContaining('탈퇴하지 못했어요'), findsOneWidget);
        expect(find.textContaining(expected), findsOneWidget);

        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();

        // 서버에는 연결이 살아 있다 — 연결 화면으로 가면 보호자 설정과 어긋난다
        expect(find.text('연결 암호 넣기'), findsNothing);
        expect(find.text('로그아웃'), findsOneWidget, reason: '설정 페이지에 머문다');
        expect(tokens.hasSession, isTrue);
        expect(storage.nickname, '하늘이');
        expect(storage.cachedTodayRoutinesJson, isNotNull);
      });
    }

    testWidgets('로그아웃 실패는 `로그아웃하지 못했어요`로 알린다 — 탈퇴와 문구가 갈린다', (tester) async {
      routes['DELETE /api/device-links/current'] = const FakeHttpError(500);
      await pump(tester);
      await openSettings(tester);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.textContaining('로그아웃하지 못했어요'), findsOneWidget);
    });
  });
}

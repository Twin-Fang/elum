import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/settings_tile.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/guardian/presentation/image_style_settings_screen.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/presentation/widgets/image_style_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/semantics_audit.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 보호자 설정의 `그림 방식` 줄과 선택 화면 (이슈 #458 · 임시 시안 opt1_A).
///
/// 서버 계약(#457): `PATCH /api/member/image-style` `{"imageStyle": "..."}`.
/// 엣지케이스 번호(E1…)는 이슈 #458 설계표와 같다.
void main() {
  useFigmaViewport();

  const patch = 'PATCH /api/member/image-style';

  late InMemoryStorage storage;
  late FakeAdapter adapter;

  /// 설정 화면 → 그림 방식 화면으로 들어가는 라우터를 통째로 올린다.
  Widget wrap({
    Object? patchResponse = const <String, Object?>{},
    Duration delay = Duration.zero,
    double textScale = 1.0,
    String? savedStyle,
  }) {
    storage = InMemoryStorage();
    // 설정 화면은 온보딩을 마친 뒤에만 열린다
    storage.setOnboardingCompleted(true);
    if (savedStyle != null) storage.setImageStyle(savedStyle);
    adapter = FakeAdapter({patch: patchResponse}, delay: delay);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;

    final router = GoRouter(
      initialLocation: Routes.guardianSettings,
      routes: [
        GoRoute(
          path: Routes.guardianSettings,
          builder: (context, state) => const GuardianSettingsScreen(),
        ),
        GoRoute(
          path: Routes.guardianImageStyle,
          builder: (context, state) => const ImageStyleSettingsScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        dioProvider.overrideWithValue(dio),
        consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
        appVersionProvider.overrideWith((ref) async => '1.47.0'),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tester.tap(find.text('그림 방식'));
    await tester.pumpAndSettle();
  }

  /// 그림 방식 저장 요청만 센다 — 설정 화면은 크레딧 카드가 다른 조회도 한다.
  List<String> styleCalls() =>
      adapter.calls.where((c) => c.contains('image-style')).toList();

  Finder card(ImageStyle style) =>
      find.byWidgetPredicate((w) => w is ImageStyleOptionCard && w.style == style);

  group('설정 줄', () {
    testWidgets('비밀암호 변경하기와 약관 사이에 있고 값과 화살표가 같이 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // 시안(1022:4467) 줄 순서를 깨지 않는다 — 다른 줄과 같은 60 간격.
      // 카드 체크 진동 줄(#515)은 그림 방식 바로 아래 들어와 약관을 한 칸 밀어 낸다.
      final ys = [
        for (final l in [
          '비밀암호 변경하기',
          '그림 방식',
          '카드 체크 진동',
          '약관 및 개인정보처리방침',
        ])
          tester.getTopLeft(find.text(l)).dy,
      ];
      expect(ys[1] - ys[0], closeTo(60, 0.5));
      expect(ys[2] - ys[1], closeTo(60, 0.5));
      expect(ys[3] - ys[2], closeTo(60, 0.5));

      final row = find.ancestor(of: find.text('그림 방식'), matching: find.byType(Row));
      expect(find.descendant(of: row, matching: find.text('만화')), findsOneWidget);
      // 앱 정보 줄과 달리 들어갈 화면이 있어 화살표가 함께 있다.
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.chevron_right_rounded)),
        findsOneWidget,
      );
    });

    testWidgets('기존 줄의 출력은 그대로다 — 앱 정보는 값만, 약관은 화살표만', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final info = find.ancestor(of: find.text('앱 정보'), matching: find.byType(Row));
      expect(
        find.descendant(of: info, matching: find.byIcon(Icons.chevron_right_rounded)),
        findsNothing,
      );
      final terms = find.ancestor(
        of: find.text('약관 및 개인정보처리방침'),
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: terms, matching: find.byIcon(Icons.chevron_right_rounded)),
        findsOneWidget,
      );
    });

    testWidgets('E13 기존 설치 앱(로컬 값 없음)은 만화로 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('만화'), findsOneWidget);
    });

    testWidgets('저장된 방식이 값으로 보인다', (tester) async {
      await tester.pumpWidget(wrap(savedStyle: 'PHOTO_ONLY'));
      await tester.pumpAndSettle();
      expect(find.text('기본 그림'), findsOneWidget);
      expect(find.text('만화'), findsNothing);
    });

    testWidgets('E2 모르는 저장값이어도 만화로 보인다', (tester) async {
      await tester.pumpWidget(wrap(savedStyle: 'ANIME'));
      await tester.pumpAndSettle();
      expect(find.text('만화'), findsOneWidget);
    });

    testWidgets('낭독기는 이름과 값을 함께 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('그림 방식')),
        containsSemantics(label: '그림 방식\n만화', hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('줄을 누르면 선택 화면이 열린다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await openScreen(tester);

      expect(find.byType(ImageStyleSettingsScreen), findsOneWidget);
    });
  });

  group('SettingsTile 확장', () {
    Widget tile({String? value, bool chevron = false}) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SettingsTile(
            label: '줄',
            onTap: () {},
            valueText: value,
            showChevronWithValue: chevron,
          ),
        ),
      ),
    );

    testWidgets('값만 주면 지금까지처럼 화살표가 없다', (tester) async {
      await tester.pumpWidget(tile(value: 'v1'));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('showChevronWithValue 면 값 옆에 화살표가 있다', (tester) async {
      await tester.pumpWidget(tile(value: '만화', chevron: true));
      expect(find.text('만화'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('값이 없으면 showChevronWithValue 와 상관없이 화살표만 있다', (tester) async {
      await tester.pumpWidget(tile(chevron: true));
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });

  group('선택 화면', () {
    testWidgets('제목과 선택지 셋의 문구가 시안대로 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await openScreen(tester);

      // 제목은 뒤로가기와 같은 줄(가운데)이다
      expect(find.text('그림 방식'), findsOneWidget);
      for (final s in ImageStyle.values) {
        expect(find.text(s.label), findsOneWidget);
        // 설명은 띄어쓰기에서만 줄바꿈하려고 끊김 방지 표시가 들어 있다 — 원문은 낭독 이름이다
        expect(
          find.byWidgetPredicate(
            (w) => w is Text && w.semanticsLabel == s.description,
          ),
          findsOneWidget,
        );
      }
      // 실사 예시는 시안의 사진 에셋, 기본 그림 예시는 픽토그램이다
      expect(imageWithAsset(AppAssets.imageStyleRealistic), findsOneWidget);
      expect(svgWithAsset(AppAssets.imageStyleBasic), findsOneWidget);
    });

    testWidgets('현재 값이 선택색(민트)으로 보이고 나머지는 흰 카드다', (tester) async {
      await tester.pumpWidget(wrap(savedStyle: 'REALISTIC'));
      await tester.pumpAndSettle();
      await openScreen(tester);

      BoxDecoration deco(ImageStyle s) {
        final c = tester.widget<AnimatedContainer>(
          // 카드 바탕이 첫 번째다(라디오 표시도 AnimatedContainer 라 뒤에 있다)
          find.descendant(of: card(s), matching: find.byType(AnimatedContainer)).first,
        );
        return c.decoration! as BoxDecoration;
      }

      expect(deco(ImageStyle.realistic).color, AppColors.light.goalSelectedFill);
      expect(deco(ImageStyle.cartoon).color, AppColors.light.surface);
      expect(deco(ImageStyle.photoOnly).color, AppColors.light.surface);
    });

    testWidgets('E10 각 선택지가 라디오로 읽히고 선택 상태를 알린다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await openScreen(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('만화, 크레딧 사용, 캐릭터가 나오는 그림이에요')),
        containsSemantics(
          label: '만화, 크레딧 사용, 캐릭터가 나오는 그림이에요',
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('실사, 크레딧 사용, 실제 물건 사진처럼 보여요')),
        containsSemantics(
          label: '실사, 크레딧 사용, 실제 물건 사진처럼 보여요',
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expectLabeledButton(tester, '뒤로 가기');
      expect(unnamedTapTargets(tester), isEmpty);
      handle.dispose();
    });

    testWidgets('실사를 고르면 서버·로컬에 저장하고 설정으로 돌아가 알린다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('실사'));
      await tester.pumpAndSettle();

      expect(adapter.sentBodies[patch], {'imageStyle': 'REALISTIC'});
      expect(storage.imageStyle, 'REALISTIC');
      // 설정으로 돌아왔고 줄의 값이 바뀌었다
      expect(find.byType(ImageStyleSettingsScreen), findsNothing);
      expect(find.text('실사'), findsOneWidget);
      // 성공은 스낵바다 (실패만 팝업)
      expect(find.text('그림 방식을 바꿨어요'), findsOneWidget);
    });

    testWidgets('E5 이미 고른 방식을 다시 누르면 요청·알림 없이 돌아간다', (tester) async {
      await tester.pumpWidget(wrap(savedStyle: 'REALISTIC'));
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('실사'));
      await tester.pumpAndSettle();

      expect(styleCalls(), isEmpty);
      expect(find.text('그림 방식을 바꿨어요'), findsNothing);
      expect(find.byType(ImageStyleSettingsScreen), findsNothing);
    });

    testWidgets('E18 저장 중에 또 눌러도 요청은 한 번이다', (tester) async {
      await tester.pumpWidget(wrap(delay: const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('실사'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('기본 그림'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(styleCalls(), [patch]);
      expect(adapter.sentBodies[patch], {'imageStyle': 'REALISTIC'});
    });

    // E3 — 서버가 거절해도 화면은 살아 있고, 이전 값으로 되돌아가고, 에러 코드가 보인다.
    testWidgets('E3 서버가 실패하면 팝업(에러 코드)을 띄우고 이전 값으로 되돌린다', (tester) async {
      await tester.pumpWidget(wrap(patchResponse: const FakeHttpError(500)));
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('실사'));
      await tester.pumpAndSettle();

      // 서버가 코드를 주지 않으면 화면 코드에 상태가 붙는다 (E-STYLE/500)
      expect(find.textContaining('E-STYLE'), findsOneWidget);
      expect(find.textContaining('그림 방식을 저장하지 못했어요'), findsOneWidget);
      expect(storage.imageStyle, isNot('REALISTIC'));
      // 스낵바는 성공에만 쓴다
      expect(find.text('그림 방식을 바꿨어요'), findsNothing);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      // 선택 화면에 그대로 있고 고른 값이 표시된다
      expect(find.byType(ImageStyleSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('E3 서버가 이유를 알려주면 그 문구·코드를 그대로 보여준다', (tester) async {
      await tester.pumpWidget(
        wrap(
          patchResponse: const FakeHttpError(
            403,
            errorCode: 'MEMBER_SUSPENDED',
            errorMessage: '정지된 계정이에요.',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('실사'));
      await tester.pumpAndSettle();

      expect(find.textContaining('정지된 계정이에요'), findsOneWidget);
    });

    testWidgets('E4 오프라인이어도 죽지 않고 에러 코드를 보여준다', (tester) async {
      await tester.pumpWidget(wrap(patchResponse: const FakeOffline()));
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('기본 그림'));
      await tester.pumpAndSettle();

      expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
      expect(storage.imageStyle, isNot('PHOTO_ONLY'));
      expect(tester.takeException(), isNull);
    });

    // 실패 팝업이 "다시 시도해주세요"라고 하는데 같은 방식을 다시 누르면 아무 일도
    // 없으면 막다른 길이다.
    testWidgets('E3·E5 실패한 뒤 같은 방식을 다시 누르면 다시 저장을 시도한다', (tester) async {
      await tester.pumpWidget(wrap(patchResponse: const FakeHttpError(500)));
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('실사'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(styleCalls().length, 1);

      await tester.tap(find.text('실사'));
      await tester.pumpAndSettle();
      expect(styleCalls().length, 2, reason: '재시도가 나가야 한다');
    });

    testWidgets('E8 글자를 200% 로 키워도 넘치지 않고 셋 다 스크롤로 닿는다', (tester) async {
      await tester.pumpWidget(wrap(textScale: 2.0));
      await tester.pumpAndSettle();
      await openScreen(tester);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('기본 그림'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('기본 그림'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('E9 작은 폰(320×568)에서도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await openScreen(tester);

      expect(tester.takeException(), isNull);
      for (final s in ImageStyle.values) {
        expect(find.text(s.label), findsOneWidget);
      }
    });

    testWidgets('뒤로가기는 아무것도 저장하지 않고 설정으로 돌아간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.bySemanticsLabel('뒤로 가기'));
      await tester.pumpAndSettle();

      expect(styleCalls(), isEmpty);
      expect(find.byType(GuardianSettingsScreen), findsOneWidget);
    });
  });
}

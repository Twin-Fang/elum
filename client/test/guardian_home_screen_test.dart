import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/recommended_routine.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/recommended_routine_strip.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// Figma `보호자_홈`(217:2655) 정합 테스트.
///
/// 디자이너가 만든 3개 시안 중 `217:2655`를 채택했다. 추천 일과가 가로 스크롤인
/// 시안이며, 하단 고정 CTA가 본문 카드로 올라온 것이 이전 구현과 가장 큰 차이다.
void main() {
  Widget wrap({
    List<Routine> routines = const [],
    Member? member,
  }) {
    final router = GoRouter(
      initialLocation: Routes.guardian,
      routes: [
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const GuardianHomeScreen(),
        ),
        GoRoute(
          path: Routes.routineInput,
          builder: (context, state) => const Scaffold(body: Text('일과 입력')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        // 실서버를 타지 않는다
        myRoutinesProvider.overrideWith((ref) async => routines),
        memberProvider.overrideWith((ref) async => member),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  Routine routine(String title, int cards) => Routine(
        id: title,
        title: title,
        steps: [
          for (var i = 0; i < cards; i++)
            ActionCard(id: '$title-$i', description: '카드 $i'),
        ],
      );

  group('보호자_홈 구성', () {
    testWidgets('Figma 섹션 문구가 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('추천 일과'), findsOneWidget);
      expect(find.text('최근 일과'), findsOneWidget);
      expect(find.text('새로운 일과 만들기'), findsOneWidget);
      expect(find.text('오늘은 어떤 일과를 준비할까요?'), findsOneWidget);
    });

    testWidgets('하단 고정 CTA가 없다', (tester) async {
      // Figma에서 "일과 만들기" 버튼이 본문 카드로 올라왔다.
      // 다시 하단 버튼을 추가하면 이 테스트가 막는다.
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(ElumButton), findsNothing);
    });

    testWidgets('아이콘을 코드로 그리지 않고 SVG 에셋으로 렌더링한다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.homeLogo), findsOneWidget);
      expect(svgWithAsset(AppAssets.homeCharacterBadge), findsOneWidget);
      expect(svgWithAsset(AppAssets.homeNewRoutineIllust), findsOneWidget);
      expect(svgWithAsset(AppAssets.iconClock), findsOneWidget);
      // sparkles는 카드와 섹션 제목 두 곳에 쓰인다
      expect(svgWithAsset(AppAssets.iconSparkles), findsWidgets);
    });

    testWidgets('서버 호칭이 있으면 인사말에 쓴다', (tester) async {
      await tester.pumpWidget(wrap(member: const Member(nickname: '하늘이')));
      await tester.pumpAndSettle();

      expect(find.text('안녕하세요,\n하늘이 보호자님 👋🏻'), findsOneWidget);
    });

    testWidgets('서버 조회가 비어도 화면이 뜬다', (tester) async {
      // 서버가 죽어도 홈은 떠야 한다 (docs 원칙 6번)
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('추천 일과'), findsOneWidget);
    });
  });

  group('추천 일과', () {
    testWidgets('Figma 4개가 순서대로 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      for (final r in RecommendedRoutine.values) {
        expect(find.text(r.label), findsOneWidget);
      }
    });

    testWidgets('가로로 스와이프된다', (tester) async {
      // Figma에서 4번째 타일이 콘텐츠 영역을 넘어간다 — 스와이프 어포던스다
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final list = tester.widget<ListView>(
        find.descendant(
          of: find.byType(RecommendedRoutineStrip),
          matching: find.byType(ListView),
        ),
      );
      expect(list.scrollDirection, Axis.horizontal);
    });

    testWidgets('타일을 누르면 문구가 채워진 채 입력 화면으로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text(RecommendedRoutine.rainyCommute.label));
      await tester.pumpAndSettle();

      expect(find.text('일과 입력'), findsOneWidget);
    });

    testWidgets('이모지는 줄바꿈 없이 한 줄로 채워진다', (tester) async {
      // 타일 표시용 줄바꿈이 서버로 그대로 나가면 안 된다
      expect(RecommendedRoutine.rainyCommute.prefillText, '비 오는 날 등교');
      expect(RecommendedRoutine.rainyCommute.prefillText, isNot(contains('\n')));
    });
  });

  group('최근 일과', () {
    testWidgets('0건이면 Figma 빈 상태를 보여준다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('아직 만든 일과가 없어요 😢'), findsOneWidget);
      expect(svgWithAsset(AppAssets.homeEmptyIllust), findsOneWidget);
    });

    testWidgets('일과가 있으면 목록으로 보여준다', (tester) async {
      await tester.pumpWidget(
        wrap(routines: [routine('비 오는 날 학교 가기', 5)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('비 오는 날 학교 가기'), findsOneWidget);
      expect(find.text('카드 5장'), findsOneWidget);
      // 목록이 있으면 빈 상태는 사라진다
      expect(find.text('아직 만든 일과가 없어요 😢'), findsNothing);
    });

    testWidgets('제목이 비어 와도 죽지 않는다', (tester) async {
      await tester.pumpWidget(wrap(routines: [routine('', 2)]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('이름 없는 일과'), findsOneWidget);
    });
  });

  group('새로운 일과 만들기', () {
    testWidgets('카드를 누르면 입력 화면으로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('새로운 일과 만들기'));
      await tester.pumpAndSettle();

      expect(find.text('일과 입력'), findsOneWidget);
    });
  });
}

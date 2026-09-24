import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/character_badge.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 캐릭터 배지는 **여우만** 둥근 사각형으로 잘라낸다 (이슈 #311).
///
/// 여우 에셋은 마스크가 셋 겹쳐 `flutter_svg` 가 온전히 못 그리고, 캐릭터가
/// 배지 밖으로 삐져나온다. 고양이까지 자르면 모서리가 깎여 시안과 어긋난다.
/// 보호자 홈만 고쳐져 있었고 이룸이 홈은 같은 에셋을 자르지 않고 그렸다.
void main() {
  useFigmaViewport();

  /// 배지 SVG 를 **바로** 감싼 ClipRRect. 화면 위쪽의 다른 ClipRRect 는 세지 않는다.
  Finder clipAround(CardCharacter character) => find.byWidgetPredicate((w) {
        if (w is! ClipRRect) return false;
        final child = w.child;
        if (child is! SvgPicture) return false;
        final loader = child.bytesLoader;
        return loader is SvgAssetLoader &&
            loader.assetName == AppAssets.characterBadgeFramed(character);
      });

  Widget screenUtil(Widget child) => ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => child,
      );

  group('CharacterBadge', () {
    Future<void> pumpBadge(WidgetTester tester, CardCharacter character) =>
        tester.pumpWidget(screenUtil(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: CharacterBadge(character: character)),
        )));

    testWidgets('여우는 모서리 16 둥근 사각형으로 잘라낸다', (tester) async {
      await pumpBadge(tester, CardCharacter.fox);

      expect(clipAround(CardCharacter.fox), findsOneWidget);
      final clip = tester.widget<ClipRRect>(clipAround(CardCharacter.fox));
      expect(clip.borderRadius, BorderRadius.circular(16.r));
    });

    testWidgets('고양이는 자르지 않는다', (tester) async {
      await pumpBadge(tester, CardCharacter.cat);

      expect(clipAround(CardCharacter.cat), findsNothing);
      expect(find.byType(ClipRRect), findsNothing);
    });
  });

  group('이룸이 홈 배지', () {
    Future<void> pumpChildHome(
      WidgetTester tester,
      CardCharacter character,
    ) async {
      final router = GoRouter(
        initialLocation: Routes.child,
        routes: [
          GoRoute(
            path: Routes.child,
            builder: (context, state) => const ChildHomeScreen(),
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          testStorageOverride(
            onboardingCompleted: true,
            character: character.apiValue,
          ),
          // 실서버를 타지 않는다
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          memberProvider.overrideWith((ref) async => null),
        ],
        child: screenUtil(
          MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('여우를 고르면 배지를 잘라낸다 — 보호자 홈과 같다', (tester) async {
      await pumpChildHome(tester, CardCharacter.fox);

      expect(find.byType(CharacterBadge), findsOneWidget);
      expect(clipAround(CardCharacter.fox), findsOneWidget);
    });

    testWidgets('고양이를 고르면 자르지 않는다', (tester) async {
      await pumpChildHome(tester, CardCharacter.cat);

      expect(find.byType(CharacterBadge), findsOneWidget);
      expect(clipAround(CardCharacter.cat), findsNothing);
    });
  });
}

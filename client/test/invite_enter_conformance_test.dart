@Tags(['golden'])
library;

import 'package:elum/core/router/routes.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/presentation/invite_enter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';

/// 초대 코드 입력의 **시안 대조용** 렌더 (Figma 1532:7114, 비어 있음 · 시작하기 꺼짐)
///
/// 골든은 앱 렌더이고, 시안 export 와는 `tool/figma_diff.py` 로 맞댄다.
const _deviceInsets = EdgeInsets.only(top: 59, bottom: 21);

void main() {
  useFigmaViewport();

  testWidgets('초대 코드 입력 — 비어 있음 (Figma 1532:7114)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          localStorageProvider.overrideWithValue(InMemoryStorage()),
          memberProvider.overrideWith((ref) async => memberWith([kProfileB])),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: _deviceInsets),
              child: child!,
            ),
            routerConfig: GoRouter(
              initialLocation: Routes.inviteEnter,
              routes: [
                GoRoute(
                  path: Routes.inviteEnter,
                  builder: (_, _) => const InviteEnterScreen(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(InviteEnterScreen),
      matchesGoldenFile('figma/inviteenter_1532-7114.png'),
    );
  });
}

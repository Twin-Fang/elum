@Tags(['golden'])
library;

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/presentation/link_enter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 이룸이 휴대폰 연결 코드 입력의 **시안 대조용** 렌더 (#493).
///
/// 시안 `코드연결` 1274:7909(비어 있음 · 시작하기 꺼짐)와 `코드연결_입력` 1274:7988
/// (`555 555` · 시작하기 켜짐). 골든은 앱 렌더이고, 시안 export 와는
/// `tool/figma_diff.py` 로 맞댄다 (`test/settings_conformance_test.dart` 와 같은 방식).
///
/// 시안은 코드 칸이 `5` 여섯 개다. 서버가 만드는 글자 집합과 달라도 이 렌더는 값 모양만
/// 본다 — 보내지 않으므로 서버 규칙과 무관하다.
const _deviceInsets = EdgeInsets.only(top: 59, bottom: 21);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceLinkRepositoryProvider.overrideWithValue(
          DeviceLinkRepository(
            dio: Dio(),
            tokens: InMemoryTokenStore(),
            storage: InMemoryStorage(),
          ),
        ),
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
            initialLocation: '/x',
            routes: [
              GoRoute(
                path: '/x',
                builder: (context, state) => const LinkEnterScreen(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  useFigmaViewport();

  testWidgets('연결 코드 입력 — 비어 있음 (Figma 1274:7909)', (tester) async {
    await _pump(tester);
    await expectLater(
      find.byType(LinkEnterScreen),
      matchesGoldenFile('figma/linkenter_1274-7909.png'),
    );
  });

  testWidgets('연결 코드 입력 — 채움 (Figma 1274:7988)', (tester) async {
    await _pump(tester);
    // 서버가 만드는 글자 집합과 상관없이 모양만 본다 — 보내지 않는다
    await tester.enterText(find.byType(TextField), '555555');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LinkEnterScreen),
      matchesGoldenFile('figma/linkenter_typed_1274-7988.png'),
    );
  });
}

@Tags(['golden'])
library;

import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/pin_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 설정 → 비밀암호 변경하기의 **시안 대조용** 렌더 (#498).
///
/// 시안 네 장 — `설정_비밀암호변경` 1027:4683(지금 암호) · 1274:9466(틀림) · 1274:9564(새 암호)
/// · 1274:9661(한번 더 + 저장하기). 골든은 앱 렌더이고 시안 export 와는 `tool/figma_diff.py`
/// 로 맞댄다. 시안의 키패드는 앱이 그리지 않는 시스템 키보드라 대조에서 가린다.
const _deviceInsets = EdgeInsets.only(top: 59, bottom: 21);

Future<void> _pump(WidgetTester tester) async {
  final storage = InMemoryStorage(onboardingCompleted: true, pin: '1234');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage)],
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
                builder: (context, state) => const PinChangeScreen(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(TextField), pin);
  await tester.pumpAndSettle();
}

void main() {
  useFigmaViewport();

  testWidgets('비밀암호 변경 — 지금 암호 (Figma 1027:4683)', (tester) async {
    await _pump(tester);
    await expectLater(
      find.byType(PinChangeScreen),
      matchesGoldenFile('figma/pinchange_verify_1027-4683.png'),
    );
  });

  testWidgets('비밀암호 변경 — 지금 암호 틀림 (Figma 1274:9466)', (tester) async {
    await _pump(tester);
    await _enter(tester, '9999');
    await expectLater(
      find.byType(PinChangeScreen),
      matchesGoldenFile('figma/pinchange_wrong_1274-9466.png'),
    );
  });

  testWidgets('비밀암호 변경 — 새 암호 (Figma 1274:9564)', (tester) async {
    await _pump(tester);
    await _enter(tester, '1234');
    await expectLater(
      find.byType(PinChangeScreen),
      matchesGoldenFile('figma/pinchange_enter_1274-9564.png'),
    );
  });

  testWidgets('비밀암호 변경 — 한번 더 + 저장하기 (Figma 1274:9661)', (tester) async {
    await _pump(tester);
    await _enter(tester, '1234');
    await _enter(tester, '5678');
    await _enter(tester, '5678');
    await expectLater(
      find.byType(PinChangeScreen),
      matchesGoldenFile('figma/pinchange_confirm_1274-9661.png'),
    );
  });
}

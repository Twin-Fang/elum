import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';

/// 일과 생성이 실패했을 때 **서버가 알려준 이유를 그대로** 보여주는지 본다.
///
/// 주간 한도에 걸린 것과 AI 가 실패한 것은 사용자가 할 일이 다르다. 둘 다
/// "잠시 후 다시 해주세요"로 뭉개면 한도에 걸린 사람은 될 때까지 다시 누른다 (#347).
Future<void> _pump(WidgetTester tester, Object? routineResponse) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeDioOverride({
          'POST /api/routines/questions': const {'questions': []},
          'POST /api/routines': ?routineResponse,
        }),
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: const RoutineLoadingScreen(kind: RoutineLoadingKind.generate),
        ),
      ),
    ),
  );
  // 로딩 단계를 지나 실패가 드러날 때까지 민다.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('한도에 걸리면 서버 문구를 그대로 띄운다', (tester) async {
    await _pump(
      tester,
      const FakeHttpError(
        403,
        errorCode: 'ROUTINE_CREATE_LIMIT_EXCEEDED',
        errorMessage: '이번 주에 만들 수 있는 일과를 다 썼어요.',
      ),
    );

    expect(find.text('이번 주에 만들 수 있는 일과를 다 썼어요.'), findsOneWidget);
    expect(
      find.text('잠시 후 다시 해주세요'),
      findsNothing,
      reason: '재시도로 풀리지 않는데 다시 하라고 하면 사용자는 계속 누른다',
    );
    // 제보 추적용 식별자는 그대로 붙는다.
    expect(find.text('ROUTINE_CREATE_LIMIT_EXCEEDED'), findsOneWidget);
  });

  testWidgets('인터넷이 끊겼으면 인터넷을 확인하라고 말한다 (#387 D4 · #352)', (tester) async {
    // 오프라인은 서버가 이유를 말해 줄 수 없다. `잠시 후 다시 해주세요` 만 띄우면
    // 끊긴 채로 계속 다시 하기를 누른다 — 무엇을 하면 되는지를 말한다.
    await _pump(tester, const FakeOffline());

    expect(find.text('카드를 만들지 못했어요'), findsOneWidget);
    expect(find.text('인터넷 연결을 확인해주세요'), findsOneWidget);
    expect(find.text('잠시 후 다시 해주세요'), findsNothing);
    expect(find.text('E-NET-OFFLINE'), findsOneWidget);
  });

  testWidgets('서버가 이유를 안 주면 앱 문구로 물러선다', (tester) async {
    await _pump(tester, null);

    expect(find.text('카드를 만들지 못했어요'), findsOneWidget);
    expect(find.text('잠시 후 다시 해주세요'), findsOneWidget);
    // **화면 코드는 그대로 남는다.** 서버 코드를 못 받으면 상태 코드를 뒤에
    // 붙이므로(`E-1001/404`) 정확히 같은 문자열은 아니다 — 제보를 받은 사람이
    // 코드베이스에서 찾을 `E-1001` 이 남아 있는지만 본다 (#352).
    expect(find.textContaining('E-1001'), findsOneWidget);
  });
}

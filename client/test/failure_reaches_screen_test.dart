import 'package:dio/dio.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// **서버가 준 문구가 실제로 화면까지 닿는가** (이슈 #352).
///
/// 단위 테스트는 [AppFailure] 가 문구를 고르는 것까지만 본다. 그 값이 화면에
/// 그려지는지는 별개다 — 실제로 화면이 `message:` 를 손으로 적고 있으면
/// 판정이 아무리 맞아도 사용자는 앱이 지어낸 말을 본다. 그래서 끝에서 끝까지 본다.
DioException _serverSays(String code, String message, {int status = 403}) {
  final options = RequestOptions(path: '/api/routines');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: {'errorCode': code, 'errorMessage': message},
    ),
  );
}

Future<void> _pump(WidgetTester tester, Object error) async {
  await tester.pumpWidget(
    ProviderScope(
      // **자동 재시도를 끈다.** Riverpod 3 은 실패한 로드를 스스로 다시 부른다
      // (`Exception` 계열만 — `Error` 는 프로그래밍 실수로 보고 재시도하지 않는다).
      // 켜 둔 채로 보면 화면이 계속 로딩이라 실패 화면을 볼 수 없다.
      retry: (count, error) => null,
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        myRoutinesProvider.overrideWith((ref) async => throw error),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          routerConfig: GoRouter(
            initialLocation: '/x',
            routes: [
              GoRoute(
                path: '/x',
                builder: (context, state) => const DraftRoutinesScreen(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  // provider 가 실패로 바뀌고 화면이 다시 그려질 때까지 민다.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  useFigmaViewport();

  testWidgets('서버가 이유를 알려주면 그 문구가 화면에 그대로 뜬다', (tester) async {
    await _pump(
      tester,
      _serverSays('MEMBER_SUSPENDED', '정지된 계정이에요'),
    );

    expect(find.text('정지된 계정이에요'), findsOneWidget);
    expect(
      find.text('임시저장을 불러오지 못했어요'),
      findsNothing,
      reason: '서버가 더 정확한 이유를 알려줬는데 앱 문구로 덮으면 안 된다',
    );
    // 제보를 받았을 때 추적할 식별자도 함께 붙는다.
    // (에러 화면은 재시도 버튼 글자에 코드를 함께 적는다.)
    expect(find.textContaining('MEMBER_SUSPENDED'), findsOneWidget);
  });

  testWidgets('서버가 아무 말도 없으면 화면 문구가 나선다', (tester) async {
    await _pump(tester, StateError('알 수 없는 실패'));

    expect(find.text('임시저장을 불러오지 못했어요'), findsOneWidget);
    expect(find.textContaining('E-DRAFT'), findsOneWidget);
  });

  testWidgets('연결이 끊겼으면 그렇게 말한다 (#341)', (tester) async {
    await _pump(
      tester,
      DioException(
        requestOptions: RequestOptions(path: '/api/routines'),
        type: DioExceptionType.connectionError,
      ),
    );

    // 문구는 화면 것을 쓰되 **코드로 원인이 갈린다** — 제보를 받으면
    // 서버가 막은 것인지 인터넷이 끊긴 것인지 바로 안다.
    expect(find.text('임시저장을 불러오지 못했어요'), findsOneWidget);
    expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
  });
}

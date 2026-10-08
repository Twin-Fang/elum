import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/logger/app_log_buffer.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/feedback/presentation/feedback_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';

/// 의견 보내기 화면 — 빈 글 차단, 성공 후 토스트와 이동, 실패 시 글 보존, 로그 첨부 선택, 키보드.
void main() {
  useFigmaViewport();

  late FakeAdapter adapter;
  late GoRouter router;

  Widget wrap(Map<String, Object?> routes) {
    adapter = FakeAdapter(routes);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('설정 화면')),
        ),
        GoRoute(
          path: Routes.guardianFeedback,
          builder: (context, state) => const FeedbackScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [testStorageOverride(), dioProvider.overrideWithValue(dio)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  Future<void> open(WidgetTester tester, Map<String, Object?> routes) async {
    await tester.pumpWidget(wrap(routes));
    await tester.pumpAndSettle();
    unawaited(router.push(Routes.guardianFeedback));
    await tester.pumpAndSettle();
  }

  ElumButton button(WidgetTester tester) =>
      tester.widget<ElumButton>(find.byType(ElumButton));

  Map<String, dynamic> sentBody() =>
      Map<String, dynamic>.from(
        adapter.sentBodies['POST /api/feedback']! as Map,
      );

  setUp(() {
    AppLogBuffer.resetForTest();
    // 앱 버전 읽기가 실제 플랫폼 채널을 기다리지 않게 한다
    PackageInfo.setMockInitialValues(
      appName: 'elum',
      packageName: 'app.elum',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDown(AppLogBuffer.resetForTest);

  testWidgets('글이 비었거나 공백뿐이면 보내기가 비활성이다', (tester) async {
    await open(tester, const {});

    expect(button(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   \n ');
    await tester.pump();
    expect(button(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '불편해요');
    await tester.pump();
    expect(button(tester).onPressed, isNotNull);
  });

  testWidgets('성공하면 토스트를 띄우고 이전 화면으로 돌아간다', (tester) async {
    AppLogBuffer.add('로그 한 줄');
    await open(tester, const {
      'POST /api/feedback': {'id': 'f1'},
    });

    await tester.enterText(find.byType(TextField), '불편해요');
    await tester.pump();
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();

    expect(find.text('설정 화면'), findsOneWidget);
    expect(find.text('의견을 보냈어요'), findsOneWidget);
    expect(sentBody()['message'], '불편해요');
    expect(sentBody()['appLog'], contains('로그 한 줄'));
  });

  testWidgets('실패하면 에러 코드를 보여 주고 적은 글과 체크 상태를 남긴다', (tester) async {
    await open(tester, const {
      'POST /api/feedback': FakeHttpError(
        429,
        errorCode: 'FEEDBACK_RATE_LIMITED',
        errorMessage: '오늘은 더 보낼 수 없어요',
      ),
    });

    await tester.enterText(find.byType(TextField), '불편해요');
    await tester.pump();
    await tester.tap(find.text('앱 상태 기록 보내기'));
    await tester.pump();
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('의견을 보내지 못했어요', findRichText: true), findsWidgets);
    expect(find.textContaining('오늘은 더 보낼 수 없어요', findRichText: true), findsWidgets);
    expect(find.textContaining('FEEDBACK_RATE_LIMITED'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('불편해요'), findsOneWidget);
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(
      tester.getSemantics(find.text('앱 상태 기록 보내기')),
      matchesSemantics(
        label: '앱 상태 기록 보내기',
        hasCheckedState: true,
        isChecked: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(button(tester).onPressed, isNotNull, reason: '다시 보낼 수 있다');
  });

  testWidgets('체크를 끄면 요청 본문에 appLog 가 없다', (tester) async {
    AppLogBuffer.add('로그 한 줄');
    await open(tester, const {
      'POST /api/feedback': {'id': 'f1'},
    });

    await tester.enterText(find.byType(TextField), '불편해요');
    await tester.tap(find.text('앱 상태 기록 보내기'));
    await tester.pump();
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();

    expect(sentBody().containsKey('appLog'), isFalse);
    expect(sentBody()['message'], '불편해요');
  });

  testWidgets('로그가 비어 있으면 appLog 없이 글만 보낸다', (tester) async {
    await open(tester, const {
      'POST /api/feedback': {'id': 'f1'},
    });

    await tester.enterText(find.byType(TextField), '불편해요');
    await tester.pump();
    await tester.tap(find.text('보내기'));
    await tester.pumpAndSettle();

    expect(sentBody().containsKey('appLog'), isFalse);
    expect(jsonEncode(sentBody()), contains('불편해요'));
  });

  testWidgets('키보드가 올라와도 보내기 버튼이 키보드 위에 있다', (tester) async {
    await open(tester, const {});

    showKeyboard(tester);
    await tester.pumpAndSettle();

    final bottom = tester.getBottomLeft(find.byType(ElumButton)).dy;
    expect(bottom, lessThanOrEqualTo(852 - 336));
  });
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status.dart';
import 'package:elum/core/app_status/app_status_gate.dart';
import 'package:elum/core/app_status/app_status_recheck.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱을 열어 둔 사람도 점검을 알아챈다 (이슈 #279 QA).
///
/// 전에는 시작할 때 한 번만 물었고, 서버도 막지 않아 점검 중에 데이터가 바뀌었다.
void main() {
  // 테스트에는 앱 버전을 읽는 플랫폼 채널이 없어 버전 조회가 끝나지 않는다.
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'elum',
        packageName: 'com.twinfang.elum',
        version: '1.23.0',
        buildNumber: '1',
        buildSignature: '',
      ));

  AppStatus status({required bool maintenance}) => AppStatus.fromJson({
        'maintenance': maintenance,
        'maintenanceMessage': '오늘 밤 10시까지 점검해요',
        'ios': {'minVersion': '', 'latestVersion': ''},
        'android': {'minVersion': '', 'latestVersion': ''},
      });

  /// 실제 Dio 요청을 거쳐, 서버가 [code]·[body] 로 거절했을 때 다시 묻는 횟수를 센다.
  Future<int> recheckCount(int code, Object? body) async {
    var asked = 0;
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        h.reject(
          DioException(
            requestOptions: o,
            response: Response(requestOptions: o, statusCode: code, data: body),
            type: DioExceptionType.badResponse,
          ),
          true, // 뒤에 붙은 인터셉터의 onError 도 타게 한다 — 실제 응답 오류와 같은 경로
        );
      }))
      ..interceptors.add(MaintenanceInterceptor(onMaintenance: () => asked++));
    await expectLater(dio.get<Object>('/api/member/me'), throwsA(isA<DioException>()));
    return asked;
  }

  group('점검 거절을 알아본다', () {
    test('503 + MAINTENANCE_MODE 이면 다시 묻는다', () async {
      expect(await recheckCount(503, {'errorCode': 'MAINTENANCE_MODE', 'errorMessage': '점검'}), 1);
    });

    test('코드 없는 503(재기동·게이트웨이)은 점검이 아니다', () async {
      expect(await recheckCount(503, '<html>Bad Gateway</html>'), 0);
      expect(await recheckCount(500, {'errorCode': 'MAINTENANCE_MODE'}), 0);
    });
  });

  group('다시 묻는다', () {
    test('신호가 올라가면 상태를 다시 가져온다', () async {
      final repo = _QueueRepository([status(maintenance: false), status(maintenance: true)]);
      final container = ProviderContainer(overrides: [
        appStatusRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      expect((await container.read(appStatusProvider.future)).status.maintenance, isFalse);
      container.read(appStatusRecheckProvider.notifier).request();
      expect((await container.read(appStatusProvider.future)).status.maintenance, isTrue);
      expect(repo.calls, 2);
    });
  });

  group('게이트', () {
    // app.dart 와 같은 자리에 둔다 — MaterialApp 의 builder 안이라 테마 확장이 보인다.
    Widget wrap(AppStatusRepository repo) => ProviderScope(
          overrides: [appStatusRepositoryProvider.overrideWithValue(repo)],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (_, _) => MaterialApp(
              theme: AppTheme.light,
              builder: (_, child) => AppStatusGate(child: child!),
              home: const Scaffold(body: Text('홈')),
            ),
          ),
        );

    testWidgets('앱이 다시 앞으로 올라오면 점검을 알아챈다', (tester) async {
      final repo = _QueueRepository([status(maintenance: false), status(maintenance: true)]);
      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsOneWidget);

      // 점검을 켠 뒤 사용자가 다른 앱에 갔다가 돌아온다
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('잠시 쉬고 있어요'), findsOneWidget);
      expect(find.text('오늘 밤 10시까지 점검해요'), findsOneWidget);
    });

    testWidgets('다시 묻는 동안 점검 화면을 유지한다 — 앱 화면이 튀어나오지 않는다', (tester) async {
      final gate = Completer<AppStatus>();
      final repo = _QueueRepository([status(maintenance: true)], then: gate.future);
      await tester.pumpWidget(wrap(repo));
      await tester.pumpAndSettle();
      expect(find.text('잠시 쉬고 있어요'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // 응답을 기다리는 중 — 뒤에 있던 홈이 잠깐이라도 그려지면 요청이 나가 503을 또 받는다
      expect(find.text('홈'), findsNothing);
      expect(find.text('잠시 쉬고 있어요'), findsOneWidget);

      gate.complete(status(maintenance: false));
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsOneWidget);
    });
  });
}

/// 준비한 응답을 차례로 돌려준다. 다 쓰면 [then] 을 기다린다.
class _QueueRepository extends AppStatusRepository {
  _QueueRepository(this._queue, {this.then}) : super(Dio());

  final List<AppStatus> _queue;
  final Future<AppStatus>? then;
  int calls = 0;

  @override
  Future<AppStatus> fetch() async {
    calls++;
    if (_queue.isNotEmpty) return _queue.removeAt(0);
    return then ?? Future.value(AppStatus.unknown);
  }
}

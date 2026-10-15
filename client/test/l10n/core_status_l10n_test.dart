import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status.dart';
import 'package:elum/core/app_status/app_status_gate.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 앱 상태 화면·코치마크가 ARB 를 읽는다 — ko 문구가 옛 화면과 같고, 서버 문구가 이긴다.
void main() {
  useFigmaViewport();
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'elum',
      packageName: 'kr.twinfang.elum',
      version: '1.23.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );

  Future<void> pumpGate(
    WidgetTester tester,
    AppStatus status, {
    Locale locale = const Locale('ko'),
  }) async {
    await pumpWithLocale(
      tester,
      AppStatusGate(child: const Scaffold(body: Text('홈'))),
      locale: locale,
      wrap: (app) => ProviderScope(
        overrides: [
          appStatusRepositoryProvider.overrideWithValue(_Fixed(status)),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('점검 화면 — 서버가 준 문구가 이긴다', (tester) async {
    await pumpGate(
      tester,
      const AppStatus(maintenance: true, maintenanceMessage: '서버 점검 중이에요'),
    );
    expect(find.text('서버 점검 중이에요'), findsOneWidget);
    expect(find.text('조금 뒤에 다시 열어주세요'), findsNothing);
  });

}

class _Fixed extends AppStatusRepository {
  _Fixed(this._status) : super(Dio());

  final AppStatus _status;

  @override
  Future<AppStatus> fetch() async => _status;
}

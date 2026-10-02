import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status.dart';
import 'package:elum/core/app_status/app_status_gate.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/widgets/coach_mark_overlay.dart';
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

  testWidgets('점검 화면 — 서버 문구가 없으면 기본 설명', (tester) async {
    await pumpGate(tester, const AppStatus(maintenance: true));
    expect(find.text('잠시 쉬고 있어요'), findsOneWidget);
    expect(find.text('조금 뒤에 다시 열어주세요'), findsOneWidget);
    expect(find.text('다시 확인하기'), findsOneWidget);
  });

  testWidgets('점검 화면 — 서버가 준 문구가 이긴다', (tester) async {
    await pumpGate(
      tester,
      const AppStatus(maintenance: true, maintenanceMessage: '서버 점검 중이에요'),
    );
    expect(find.text('서버 점검 중이에요'), findsOneWidget);
    expect(find.text('조금 뒤에 다시 열어주세요'), findsNothing);
  });

  testWidgets(
    '강제 업데이트 화면 — 설명은 두 줄이고 주소가 없으면 업데이트했어요 버튼',
    (tester) async {
      await pumpGate(tester, const AppStatus(minVersion: '9.0.0'));
      expect(find.text('새 이룸이 나왔어요'), findsOneWidget);
      expect(
        find.text('앱을 새로 받아야 이어서 쓸 수 있어요.\n스토어에서 이룸을 업데이트해주세요'),
        findsOneWidget,
      );
      expect(find.text('업데이트했어요'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.fuchsia),
  );

  testWidgets(
    '강제 업데이트 화면 — 스토어 주소가 있으면 업데이트하러 가기 버튼',
    (tester) async {
      await pumpGate(tester, const AppStatus(minVersion: '9.0.0'));
      expect(find.text('업데이트하러 가기'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('번역이 비어 있는 언어(ja)는 ko 문구로 떨어진다', (tester) async {
    await pumpGate(
      tester,
      const AppStatus(maintenance: true),
      locale: const Locale('ja'),
    );
    expect(find.text('잠시 쉬고 있어요'), findsOneWidget);
  });

  testWidgets('코치마크 — 중간 단계는 다음으로, 마지막 단계는 닫힘 안내', (tester) async {
    final a = GlobalKey();
    final b = GlobalKey();
    var index = 0;
    final handle = tester.ensureSemantics();
    await pumpWithLocale(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Stack(
          children: [
            Positioned(
              left: 20,
              top: 100,
              child: SizedBox(key: a, width: 100, height: 50),
            ),
            Positioned(
              left: 20,
              top: 300,
              child: SizedBox(key: b, width: 100, height: 50),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: CoachMarkOverlay(
                  steps: [
                    CoachMarkStep(target: a, message: '첫째'),
                    CoachMarkStep(target: b, message: '둘째'),
                  ],
                  index: index,
                  visible: true,
                  onNext: () => setState(() => index++),
                  onClose: () {},
                  onDismissed: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('화면을 누르면 다음으로 넘어가요'), findsOneWidget);
    expect(find.bySemanticsLabel('안내 1/2. 첫째'), findsOneWidget);
    expect(find.bySemanticsLabel('안내 닫기'), findsOneWidget);

    await tester.tapAt(const Offset(200, 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('화면을 누르면 닫혀요'), findsOneWidget);
    expect(find.bySemanticsLabel('안내 2/2. 둘째'), findsOneWidget);
    handle.dispose();
  });
}

class _Fixed extends AppStatusRepository {
  _Fixed(this._status) : super(Dio());

  final AppStatus _status;

  @override
  Future<AppStatus> fetch() async => _status;
}

import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status.dart';
import 'package:elum/core/app_status/app_status_gate.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/app_status/store_launcher.dart';
import 'package:elum/core/config/app_config.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 강제 업데이트 화면에서 스토어로 바로 보낸다 (이슈 #279 남은 일).
///
/// 전에는 "스토어에서 이룸을 업데이트해주세요" 문구뿐이라 사용자가 스토어를 직접
/// 찾아가야 했다. iOS 는 첫 출시로 App Store 앱 ID 를 받아 같은 버튼을 켠다.
void main() {
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'elum',
        packageName: 'kr.twinfang.elum',
        version: '1.23.0',
        buildNumber: '1',
        buildSignature: '',
      ));
  // 플랫폼은 variant 로 바꾼다 — 테스트 안에서 끝나기 전에 되돌려 준다.
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  // 최소 버전이 지금(1.23.0)보다 높다 → 강제 업데이트 화면
  const mustUpdate = AppStatus(minVersion: '9.0.0');

  Widget wrap({required StoreLauncher launcher}) => ProviderScope(
        overrides: [
          appStatusRepositoryProvider.overrideWithValue(_FixedRepository(mustUpdate)),
          storeLauncherProvider.overrideWithValue(launcher),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.light,
            builder: (_, child) => AppStatusGate(child: child!),
            home: const Scaffold(body: Text('홈')),
          ),
        ),
      );

  group('스토어 주소', () {
    test('안드로이드는 Play 스토어의 이룸 상세로 보낸다', () {
      expect(
        AppConfig.storeUrl(TargetPlatform.android),
        Uri.parse('https://play.google.com/store/apps/details?id=kr.twinfang.elum'),
      );
    });

    test('iOS 는 App Store 앱을 바로 열어 이룸 상세로 보낸다', () {
      // 브라우저를 거치지 않도록 itms-apps 스킴을 쓴다
      expect(
        AppConfig.storeUrl(TargetPlatform.iOS),
        Uri.parse('itms-apps://apps.apple.com/app/id6792970508'),
      );
    });
  });

  group('강제 업데이트 화면', () {
    testWidgets('안드로이드 — 업데이트하러 가기를 누르면 Play 스토어를 연다', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(wrap(launcher: (url) async {
        opened.add(url);
        return true;
      }));
      await tester.pumpAndSettle();

      expect(find.text('새 이룸이 나왔어요'), findsOneWidget);
      // 누를 것은 하나만 — 스토어에서 돌아오면 앱이 알아서 다시 확인한다
      expect(find.text('업데이트했어요'), findsNothing);

      await tester.tap(find.text('업데이트하러 가기'));
      await tester.pumpAndSettle();

      expect(opened, [AppConfig.storeUrl(TargetPlatform.android)]);
      expect(find.textContaining('E-UPDATE-STORE'), findsNothing);
    }, variant: android);

    testWidgets('스토어를 열지 못하면 에러 코드와 함께 알린다', (tester) async {
      await tester.pumpWidget(wrap(launcher: (_) async => false));
      await tester.pumpAndSettle();

      await tester.tap(find.text('업데이트하러 가기'));
      await tester.pumpAndSettle();

      expect(find.text('스토어를 열지 못했어요'), findsOneWidget);
      expect(find.textContaining('E-UPDATE-STORE'), findsOneWidget);

      // 닫으면 업데이트 화면으로 돌아와 다시 누를 수 있다
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('업데이트하러 가기'), findsOneWidget);
    }, variant: android);

    testWidgets('여는 중 예외가 나도 화면이 깨지지 않고 알린다', (tester) async {
      await tester.pumpWidget(wrap(launcher: (_) => throw StateError('채널 없음')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('업데이트하러 가기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('E-UPDATE-STORE'), findsOneWidget);
    }, variant: android);

    testWidgets('iOS — 업데이트하러 가기를 누르면 App Store 를 연다', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(wrap(launcher: (url) async {
        opened.add(url);
        return true;
      }));
      await tester.pumpAndSettle();

      expect(find.text('업데이트했어요'), findsNothing);

      await tester.tap(find.text('업데이트하러 가기'));
      await tester.pumpAndSettle();

      expect(opened, [AppConfig.storeUrl(TargetPlatform.iOS)]);
    }, variant: ios);
  });
}

class _FixedRepository extends AppStatusRepository {
  _FixedRepository(this._status) : super(Dio());

  final AppStatus _status;

  @override
  Future<AppStatus> fetch() async => _status;
}

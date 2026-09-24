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

  Widget wrap({required StoreLauncher launcher, AppStatus status = mustUpdate}) =>
      ProviderScope(
        overrides: [
          appStatusRepositoryProvider.overrideWithValue(_FixedRepository(status)),
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

  // 서버가 준 주소가 앱에 박힌 주소보다 먼저다 (#416). 이 화면은 옛 버전 앱에서 뜨므로
  // 서버에서 바꿀 수 있어야 이미 깔린 앱도 보낼 곳을 고칠 수 있다.
  group('서버가 준 스토어 주소', () {
    const iosServer = 'https://apps.apple.com/kr/app/id6792970508';
    const androidServer = 'market://details?id=kr.twinfang.elum';

    test('스토어 주소면 서버 값을 쓴다', () {
      expect(AppConfig.storeUrl(TargetPlatform.iOS, serverUrl: iosServer),
          Uri.parse(iosServer));
      expect(AppConfig.storeUrl(TargetPlatform.android, serverUrl: androidServer),
          Uri.parse(androidServer));
    });

    test('비었거나 옛 서버라 없으면 앱에 넣어 둔 주소를 쓴다', () {
      expect(AppConfig.storeUrl(TargetPlatform.iOS, serverUrl: ''),
          AppConfig.storeUrl(TargetPlatform.iOS));
      expect(AppConfig.storeUrl(TargetPlatform.android, serverUrl: '  '),
          AppConfig.storeUrl(TargetPlatform.android));
    });

    test('스토어 주소가 아니거나 플랫폼이 다르면 무시한다', () {
      for (final bad in [
        'http://apps.apple.com/app/id1',
        'https://apps.apple.com.evil.com/app/id1',
        'https://example.com',
        'https://play.google.com/store/apps/details?id=kr.twinfang.elum',
        '이상한 값',
      ]) {
        expect(AppConfig.storeUrl(TargetPlatform.iOS, serverUrl: bad),
            AppConfig.storeUrl(TargetPlatform.iOS),
            reason: bad);
      }
      expect(
        AppConfig.storeUrl(TargetPlatform.android, serverUrl: iosServer),
        AppConfig.storeUrl(TargetPlatform.android),
      );
    });

    test('응답의 플랫폼 칸에서 storeUrl 을 읽는다 — 형식이 달라도 죽지 않는다', () {
      // 테스트는 호스트(macOS)에서 돌아 Platform.isIOS 가 false → android 칸을 읽는다
      final status = AppStatus.fromJson({
        'android': {'minVersion': '1.0.0', 'storeUrl': ' $androidServer '},
      });
      expect(status.storeUrl, androidServer);
      expect(AppStatus.fromJson({'android': {'storeUrl': 3}}).storeUrl, isEmpty);
      expect(AppStatus.fromJson({}).storeUrl, isEmpty);
    });

    testWidgets('업데이트하러 가기는 서버가 준 주소를 연다', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(wrap(
        status: const AppStatus(minVersion: '9.0.0', storeUrl: androidServer),
        launcher: (url) async {
          opened.add(url);
          return true;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('업데이트하러 가기'));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse(androidServer)]);
    }, variant: android);
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

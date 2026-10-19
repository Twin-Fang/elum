import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:elum/core/logger/app_log_buffer.dart';
import 'package:elum/core/logger/app_log_diagnostics.dart';
import 'package:elum/core/logger/app_log_header.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 의견에 진단 정보가 없으면 설치 경로·서명 해시를 몰라 로그인 실패 원인을 못 가린다 (#772)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const diagnosticsChannel = MethodChannel(AppLogDiagnostics.channelName);
  const installationChannel = MethodChannel('elum/installation');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockNative(Future<Object?> Function(MethodCall call)? handler) =>
      messenger.setMockMethodCallHandler(diagnosticsChannel, handler);

  setUp(() {
    AppLogBuffer.resetForTest();
    messenger.setMockMethodCallHandler(
      installationChannel,
      (_) async => 'install-id-1',
    );
  });

  tearDown(() {
    mockNative(null);
    messenger.setMockMethodCallHandler(installationChannel, null);
  });

  AppLogDiagnostics build({
    Future<String> Function()? kakaoKeyHash,
    Future<List<ConnectivityResult>> Function()? connectivity,
  }) => AppLogDiagnostics(
    readKakaoKeyHash: kakaoKeyHash ?? () async => 'sdk-hash=',
    readConnectivity: connectivity ?? () async => [ConnectivityResult.wifi],
    readDeviceModel: () async => 'samsung SM-S911 (Android 15, SDK 35)',
  );

  test('스토어 설치본의 설치 경로와 서명 해시, 카카오톡 버전을 남긴다', () async {
    mockNative(
      (_) async => {
        'installerPackage': 'com.android.vending',
        'signingKeyHashes': ['hashA=', 'hashB='],
        'kakaoTalkVersion': '10.9.1',
        'isPowerSaveMode': false,
        'freeStorageBytes': 5 * 1024 * 1024 * 1024,
      },
    );

    final section = await build().buildSection();

    expect(section, contains('설치 경로: Play 스토어'));
    expect(section, contains('서명 키 해시: hashA=, hashB='));
    expect(section, contains('카카오톡: 10.9.1'));
    expect(section, contains('카카오 SDK 키 해시: sdk-hash='));
    expect(section, contains('설치 식별자: install-id-1'));
    expect(section, contains('연결: wifi'));
    expect(section, contains('저전력 모드: 아니오'));
  });

  test('스토어가 아닌 직접 설치와 카카오톡 미설치를 구분한다', () async {
    mockNative(
      (_) async => {
        'installerPackage': '',
        'signingKeyHashes': ['hashX='],
        'kakaoTalkVersion': '',
      },
    );

    final section = await build().buildSection();

    expect(section, contains('설치 경로: 직접 설치 (스토어 아님)'));
    expect(section, contains('카카오톡: 미설치'));
  });

  test('네이티브 호출과 SDK 읽기가 모두 실패해도 예외 없이 - 로 채운다', () async {
    mockNative((_) async => throw PlatformException(code: 'E-NATIVE'));
    messenger.setMockMethodCallHandler(
      installationChannel,
      (_) async => throw PlatformException(code: 'E-INSTALL'),
    );

    final section = await build(
      kakaoKeyHash: () async => throw StateError('sdk not initialized'),
      connectivity: () async => throw StateError('no plugin'),
    ).buildSection();

    expect(section, contains('설치 경로: -'));
    expect(section, contains('서명 키 해시: -'));
    expect(section, contains('설치 식별자: -'));
    expect(section, contains('카카오 SDK 키 해시: -'));
    expect(section, contains('연결: -'));
    expect(section, contains('기기: samsung SM-S911'));
  });

  test('마지막 소셜 로그인 오류를 한 줄로 남긴다', () async {
    mockNative((_) async => <String, Object?>{});
    AppLogBuffer.addError(
      'category: 소셜 로그인 카카오 | error: {error: misconfigured, '
      'error_description: Android keyHash validation failed.}',
    );

    final section = await build().buildSection();

    expect(section, contains('keyHash validation failed'));
  });

  test('머리글은 기존 항목 뒤에 진단 구역을 붙인다', () async {
    mockNative((_) async => <String, Object?>{});

    final header = await buildAppLogHeader(diagnostics: build());

    expect(header, startsWith('앱: '));
    expect(header.indexOf('== 진단 =='), greaterThan(header.indexOf('화면 크기')));
  });

  test('진단 구역 생성이 통째로 실패해도 기존 머리글은 보낸다', () async {
    final header = await buildAppLogHeader(diagnostics: _ThrowingDiagnostics());

    expect(header, startsWith('앱: '));
    expect(header, isNot(contains('== 진단 ==')));
  });
}

class _ThrowingDiagnostics extends AppLogDiagnostics {
  @override
  Future<String> buildSection() async => throw StateError('boom');
}

import 'dart:convert';
import 'package:elum/core/storage/installation_store.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const installation = MethodChannel('elum/installation');
  late Map<String, String> values;
  String? failMethod;
  String? failKey;
  final jwt =
      'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'member-1'})))}.x';
  setUp(() {
    values = {};
    failMethod = null;
    failKey = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String;
          if (call.method == failMethod &&
              (failKey == null || key == failKey)) {
            throw PlatformException(code: 'unavailable');
          }
          switch (call.method) {
            case 'read':
              return values[key];
            case 'write':
              values[key] = args['value'] as String;
              return null;
            case 'delete':
              values.remove(key);
              return null;
          }
          return null;
        });
  });
  test('같은 설치 재시작은 세션 유지', () async {
    final store = SecureTokenStore(installationId: 'same');
    await store.save(accessToken: jwt, refreshToken: 'refresh');
    final restarted = SecureTokenStore(installationId: 'same');
    await restarted.load();
    expect(restarted.hasSession, true);
    expect(restarted.installationChanged, false);
  });
  test('Keychain 잔존 새 설치는 세션을 거부하고 소유자만 보존', () async {
    values.addAll({
      'elum.accessToken': jwt,
      'elum.refreshToken': 'refresh',
      'elum.tokenInstallation': 'old',
    });
    final store = SecureTokenStore(
      installationId: 'new',
      allowLegacyMigration: true,
    );
    await store.load();
    expect(store.hasSession, false);
    expect(store.installationChanged, true);
    expect(store.previousMemberId, 'member-1');
    final restarted = SecureTokenStore(installationId: 'new');
    await restarted.load();
    expect(restarted.previousMemberId, 'member-1');
    expect(restarted.hasSession, false);
  });
  test('일관된 기존 설치만 표식 없는 토큰을 일회 이전', () async {
    values.addAll({'elum.accessToken': jwt, 'elum.refreshToken': 'refresh'});
    final store = SecureTokenStore(
      installationId: 'new',
      allowLegacyMigration: true,
    );
    await store.load();
    expect(store.hasSession, true);
    expect(store.installationChanged, false);
    expect(values['elum.tokenInstallation'], 'new');
  });
  test('로컬 자료 없는 재설치는 legacy 토큰 거부', () async {
    values.addAll({'elum.accessToken': jwt, 'elum.refreshToken': 'refresh'});
    final store = SecureTokenStore(installationId: 'new');
    await store.load();
    expect(store.hasSession, false);
  });
  test('보안 저장소 읽기 실패는 시작을 닫는다', () async {
    failMethod = 'read';
    final store = SecureTokenStore(installationId: 'same');
    await expectLater(store.load(), throwsA(isA<InstallationException>()));
    expect(store.hasSession, false);
  });
  test('부분 저장 실패는 재실행 legacy 이전으로 우회할 수 없다', () async {
    final store = SecureTokenStore(installationId: 'same');
    await store.save(accessToken: jwt, refreshToken: 'old');
    failMethod = 'write';
    failKey = 'elum.refreshToken';
    await expectLater(
      store.save(accessToken: jwt, refreshToken: 'new'),
      throwsA(isA<InstallationException>()),
    );
    expect(store.hasSession, false);
    failMethod = null;
    final restart = SecureTokenStore(
      installationId: 'same',
      allowLegacyMigration: true,
    );
    await restart.load();
    expect(restart.hasSession, false);
  });
  test('삭제 실패도 세션 복원 결합부터 끊는다', () async {
    final store = SecureTokenStore(installationId: 'same');
    await store.save(accessToken: jwt, refreshToken: 'refresh');
    failMethod = 'delete';
    await expectLater(store.clear(), throwsA(isA<InstallationException>()));
    expect(store.hasSession, false);
    failMethod = null;
    final restarted = SecureTokenStore(
      installationId: 'same',
      allowLegacyMigration: true,
    );
    await restarted.load();
    expect(restarted.hasSession, false);
  });
  test('설치 표식 오류/빈 값은 신규 설치로 대체하지 않는다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          installation,
          (_) async => throw PlatformException(code: 'E-INSTALL'),
        );
    await expectLater(
      const InstallationStore().load(),
      throwsA(isA<InstallationException>()),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(installation, (_) async => '');
    await expectLater(
      const InstallationStore().load(),
      throwsA(isA<InstallationException>()),
    );
  });
  test('legacy 이전은 로컬 앱 상태가 하나라도 남았으면 허용', () async {
    // 재설치는 로컬 상태가 비어 있다.
    expect(canMigrateLegacyInstallation(InMemoryStorage()), false);

    // 프로필 ID·이름이 비어 있는 이룸이 휴대폰도 업데이트로 로그아웃되지 않는다.
    final elumi = InMemoryStorage();
    await elumi.setElumiDevice(true);
    expect(canMigrateLegacyInstallation(elumi), true);

    final guardian = InMemoryStorage();
    await guardian.setOnboardingCompleted(true);
    expect(canMigrateLegacyInstallation(guardian), true);

    // 온보딩 도중(역할만 고른 상태)도 세션을 이어 간다.
    final midOnboarding = InMemoryStorage();
    await midOnboarding.setSelectedRole('guardian');
    expect(canMigrateLegacyInstallation(midOnboarding), true);
  });
  testWidgets('설치 오류 화면은 코드와 재시도를 제공', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      InstallationRetryApp(
        onRetry: () async {
          retries++;
        },
      ),
    );
    expect(find.text('E-INSTALL'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(retries, 1);
  });
}

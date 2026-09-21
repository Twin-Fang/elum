import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status.dart';
import 'package:elum/core/config/app_config.dart';
import 'package:elum/core/config/client_tuning.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 대기·연출 시간값을 서버에서 받는다.
///
/// 전에는 `.env` 에 있어 값 하나를 바꾸려 해도 앱을 다시 빌드해야 했다.
void main() {
  tearDown(AppConfig.resetTuning); // 정적 값이라 테스트끼리 새어 나간다

  Map<String, dynamic> serverClient({int consent = 5000}) => {
        'connectTimeoutMs': 8000,
        'receiveTimeoutMs': 90000,
        'loadingMaxWaitMs': 30000,
        'consentFetchTimeoutMs': consent,
        'dlpMinDelayMs': 0,
      };

  group('서버 값을 읽는다', () {
    test('다섯 값을 그대로 읽는다', () {
      final t = ClientTuning.tryParse(serverClient())!;
      expect(t.connectTimeout, const Duration(seconds: 8));
      expect(t.receiveTimeout, const Duration(seconds: 90));
      expect(t.loadingMaxWait, const Duration(seconds: 30));
      expect(t.consentFetchTimeout, const Duration(seconds: 5));
      expect(t.dlpMinDelay, Duration.zero, reason: '0 은 "연출하지 않음"이라 받는다');
    });

    test('범위를 벗어난 값은 그 항목만 기본값이다 — 0초 대기는 끝없이 기다리기다', () {
      final t = ClientTuning.tryParse({
        ...serverClient(),
        'connectTimeoutMs': 0,
        'receiveTimeoutMs': -1,
        'consentFetchTimeoutMs': 999999,
      })!;
      expect(t.connectTimeoutMs, ClientTuning.defaults.connectTimeoutMs);
      expect(t.receiveTimeoutMs, ClientTuning.defaults.receiveTimeoutMs);
      expect(t.consentFetchTimeoutMs, ClientTuning.defaults.consentFetchTimeoutMs);
      expect(t.loadingMaxWaitMs, 30000, reason: '멀쩡한 값은 그대로 쓴다');
    });

    test('항목이 빠지거나 숫자가 아니면 그 항목만 기본값이다', () {
      final t = ClientTuning.tryParse({'connectTimeoutMs': '8000'})!;
      expect(t, ClientTuning.defaults);
    });

    test('형식이 통째로 다르면 받지 않는다', () {
      expect(ClientTuning.tryParse(null), isNull);
      expect(ClientTuning.tryParse('10000'), isNull);
      expect(ClientTuning.tryParseJson('{ 깨진'), isNull);
      expect(ClientTuning.tryParseJson(null), isNull);
    });

    test('저장했다 다시 읽으면 같다', () {
      final t = ClientTuning.tryParse(serverClient())!;
      expect(ClientTuning.tryParseJson(t.toJson()), t);
    });
  });

  group('앱이 쓰는 값', () {
    test('한 번도 받지 않았으면 코드 기본값이다', () {
      expect(AppConfig.connectTimeout, const Duration(seconds: 10));
      expect(AppConfig.receiveTimeout, const Duration(seconds: 60));
      expect(AppConfig.loadingMaxWait, const Duration(seconds: 45));
      expect(AppConfig.consentFetchTimeout, const Duration(seconds: 3));
      expect(AppConfig.dlpMinDelay, const Duration(milliseconds: 1500));
      expect(AppConfig.tuningSource, TuningSource.defaults);
    });

    test('서버 값을 받으면 지금 바로 바뀌고, 이미 만든 Dio 에도 적용된다', () {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      final storage = InMemoryStorage();

      applyServerTuning(ClientTuning.tryParse(serverClient())!, dio: dio, storage: storage);

      expect(AppConfig.consentFetchTimeout, const Duration(seconds: 5));
      expect(AppConfig.tuningSource, TuningSource.server);
      expect(dio.options.connectTimeout, const Duration(seconds: 8),
          reason: '다음 실행까지 기다리지 않는다');
      expect(dio.options.receiveTimeout, const Duration(seconds: 90));
      // 다음 실행은 서버에 닿기 전 첫 요청부터 이 값으로 돈다
      expect(ClientTuning.tryParseJson(storage.cachedClientTuningJson),
          ClientTuning.tryParse(serverClient()));
    });

    test('저장에 실패해도 이번 실행은 새 값으로 돈다 — 동기 예외', () {
      applyServerTuning(ClientTuning.tryParse(serverClient())!, dio: Dio(), storage: _BlockedStorage());
      expect(AppConfig.consentFetchTimeout, const Duration(seconds: 5));
    });

    test('저장에 실패해도 이번 실행은 새 값으로 돈다 — 비동기 실패도 새지 않는다', () async {
      applyServerTuning(ClientTuning.tryParse(serverClient())!, dio: Dio(), storage: _AsyncFailingStorage());
      await Future<void>.delayed(Duration.zero); // 실패한 Future 가 처리되지 않으면 여기서 테스트가 깨진다
      expect(AppConfig.consentFetchTimeout, const Duration(seconds: 5));
    });
  });

  group('앱 상태 응답', () {
    Map<String, dynamic> status({Object? client}) => {
          'maintenance': false,
          'maintenanceMessage': '',
          'ios': {'minVersion': '', 'latestVersion': ''},
          'android': {'minVersion': '', 'latestVersion': ''},
          'client': ?client,
        };

    test('client 를 읽는다', () {
      expect(AppStatus.fromJson(status(client: serverClient())).tuning,
          ClientTuning.tryParse(serverClient()));
    });

    test('옛 서버라 client 가 없으면 null — 지금 값을 그대로 쓴다', () {
      expect(AppStatus.fromJson(status()).tuning, isNull);
    });
  });
}

class _AsyncFailingStorage extends InMemoryStorage {
  @override
  Future<void> setCachedClientTuningJson(String json) async => throw Exception('디스크 가득 참');
}

class _BlockedStorage extends InMemoryStorage {
  @override
  Future<void> setCachedClientTuningJson(String json) => throw Exception('저장소 막힘');
}

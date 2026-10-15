import 'package:dio/dio.dart';
import 'package:elum/core/config/app_config.dart';
import 'package:elum/core/config/client_tuning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

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

    test('형식이 통째로 다르면 받지 않는다', () {
      expect(ClientTuning.tryParse(null), isNull);
      expect(ClientTuning.tryParse('10000'), isNull);
      expect(ClientTuning.tryParseJson('{ 깨진'), isNull);
      expect(ClientTuning.tryParseJson(null), isNull);
    });

  });

  group('앱이 쓰는 값', () {

    test('저장에 실패해도 이번 실행은 새 값으로 돈다 — 동기 예외', () {
      applyServerTuning(ClientTuning.tryParse(serverClient())!, dio: Dio(), storage: _BlockedStorage());
      expect(AppConfig.consentFetchTimeout, const Duration(seconds: 5));
    });

  });

}

class _BlockedStorage extends InMemoryStorage {
  @override
  Future<void> setCachedClientTuningJson(String json) => throw Exception('저장소 막힘');
}

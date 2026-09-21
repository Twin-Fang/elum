import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/local_storage.dart';
import 'app_config.dart';

/// 앱의 대기·연출 시간값. **서버가 주고 관리자 화면에서 고친다.**
///
/// 전에는 앱의 `.env` 에 있어서 값 하나를 바꾸려 해도 앱을 다시 빌드해 심사를 받아야
/// 했다. 이제 코드에는 기본값만 두고, 실제 값은 서버 DB에 있다.
///
/// | 순서 | 어디서 | 언제 |
/// |---|---|---|
/// | 1 | 서버 (`/api/app/status` 의 `client`) | 앱이 뜬 뒤 받자마자 |
/// | 2 | 지난번에 받아 저장해 둔 값 | 앱이 뜰 때 — 서버에 닿기 전 첫 요청부터 |
/// | 3 | 아래 [defaults] | 한 번도 받지 못했을 때 |
///
/// **범위를 벗어난 값은 그 항목만 기본값으로 떨어진다.** 서버도 범위를 막지만, 0이 들어오면
/// 요청이 끝없이 기다리게 되므로 앱에서 한 번 더 거른다. 범위는 서버 `ConfigKey` 와 같다.
@immutable
class ClientTuning {
  const ClientTuning({
    required this.connectTimeoutMs,
    required this.receiveTimeoutMs,
    required this.loadingMaxWaitMs,
    required this.consentFetchTimeoutMs,
    required this.dlpMinDelayMs,
  });

  /// 서버 `ConfigKey` 의 기본값과 같다. 서버를 못 봐도 같은 값으로 돈다.
  static const defaults = ClientTuning(
    connectTimeoutMs: 10000,
    receiveTimeoutMs: 60000,
    loadingMaxWaitMs: 45000,
    consentFetchTimeoutMs: 3000,
    dlpMinDelayMs: 1500,
  );

  final int connectTimeoutMs;
  final int receiveTimeoutMs;
  final int loadingMaxWaitMs;
  final int consentFetchTimeoutMs;
  final int dlpMinDelayMs;

  Duration get connectTimeout => Duration(milliseconds: connectTimeoutMs);
  Duration get receiveTimeout => Duration(milliseconds: receiveTimeoutMs);
  Duration get loadingMaxWait => Duration(milliseconds: loadingMaxWaitMs);
  Duration get consentFetchTimeout => Duration(milliseconds: consentFetchTimeoutMs);
  Duration get dlpMinDelay => Duration(milliseconds: dlpMinDelayMs);

  /// 서버가 준 `client` 를 읽는다. 형식이 통째로 다르면 null 이다.
  static ClientTuning? tryParse(Object? raw) {
    if (raw is! Map) return null;
    int pick(String key, int fallback, int min, int max) {
      final value = raw[key];
      if (value is! int || value < min || value > max) return fallback;
      return value;
    }

    const d = defaults;
    return ClientTuning(
      connectTimeoutMs: pick('connectTimeoutMs', d.connectTimeoutMs, 1000, 60000),
      receiveTimeoutMs: pick('receiveTimeoutMs', d.receiveTimeoutMs, 5000, 180000),
      loadingMaxWaitMs: pick('loadingMaxWaitMs', d.loadingMaxWaitMs, 10000, 180000),
      consentFetchTimeoutMs: pick('consentFetchTimeoutMs', d.consentFetchTimeoutMs, 1000, 15000),
      dlpMinDelayMs: pick('dlpMinDelayMs', d.dlpMinDelayMs, 0, 10000),
    );
  }

  static ClientTuning? tryParseJson(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return tryParse(jsonDecode(json));
    } on FormatException {
      return null;
    }
  }

  String toJson() => jsonEncode({
        'connectTimeoutMs': connectTimeoutMs,
        'receiveTimeoutMs': receiveTimeoutMs,
        'loadingMaxWaitMs': loadingMaxWaitMs,
        'consentFetchTimeoutMs': consentFetchTimeoutMs,
        'dlpMinDelayMs': dlpMinDelayMs,
      });

  @override
  bool operator ==(Object other) =>
      other is ClientTuning &&
      other.connectTimeoutMs == connectTimeoutMs &&
      other.receiveTimeoutMs == receiveTimeoutMs &&
      other.loadingMaxWaitMs == loadingMaxWaitMs &&
      other.consentFetchTimeoutMs == consentFetchTimeoutMs &&
      other.dlpMinDelayMs == dlpMinDelayMs;

  @override
  int get hashCode => Object.hash(connectTimeoutMs, receiveTimeoutMs,
      loadingMaxWaitMs, consentFetchTimeoutMs, dlpMinDelayMs);
}

/// 서버에서 받은 시간값을 **지금 바로** 적용하고 다음 실행을 위해 저장한다.
///
/// 이미 만들어진 Dio 의 대기 시간도 바꾼다 — 그러지 않으면 다음 실행까지 옛 값으로 돈다.
/// 저장에 실패해도 이번 실행은 새 값으로 돈다. 다음에 또 받으면 된다.
void applyServerTuning(
  ClientTuning tuning, {
  required Dio dio,
  required LocalStorage storage,
}) {
  AppConfig.applyTuning(tuning, source: TuningSource.server);
  dio.options
    ..connectTimeout = tuning.connectTimeout
    ..receiveTimeout = tuning.receiveTimeout;
  void warn(Object e) => debugPrint('[config] 시간값을 저장하지 못했다 — 이번 실행만 적용: $e');
  // 저장소는 실패를 동기 예외로도, 실패한 Future 로도 알린다. 둘 다 잡지 않으면 비동기
  // 실패가 처리되지 않은 채 남는다.
  try {
    unawaited(storage.setCachedClientTuningJson(tuning.toJson()).catchError(warn));
  } catch (e) {
    warn(e);
  }
}

/// 지금 쓰는 시간값이 어디서 왔나. 개발자 도구에 보여 준다.
enum TuningSource { defaults, cached, server }

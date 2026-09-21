import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../domain/consent_bundle.dart';

/// 약관 전문을 어디서 읽을지 고른다 (이슈 #278).
///
/// ## 왜 세 층인가
///
/// 서버로만 옮기면 **네트워크가 없을 때 가입이 막힌다.** 동의는 "읽을 수 있는
/// 상태에서 받아야" 성립하므로, 읽을 것이 없으면 동의를 받을 수 없다.
///
/// | 층 | 언제 쓰나 |
/// |---|---|
/// | 서버 | 평소. 관리자가 고친 최신본 |
/// | 캐시 | 서버를 못 봤을 때. 지난번에 받아 둔 것 |
/// | 앱 번들 | 첫 실행에 네트워크까지 없을 때 |
///
/// **어떤 실패도 예외로 새어 나가지 않는다.** 약관을 못 받았다고 앱이 죽거나
/// 가입이 막히면, 서버가 잠깐 흔들릴 때 신규 가입이 통째로 멈춘다.
class ConsentDocumentRepository {
  ConsentDocumentRepository({required Dio dio, required LocalStorage storage})
      : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final LocalStorage _storage;

  /// 서버를 기다리는 상한.
  ///
  /// 동의 화면은 로그인 직후에 선다. 여기서 오래 붙들면 **로그인이 실패한 것처럼**
  /// 보인다. 짧게 끊고 캐시로 넘어가는 편이 낫다 — 캐시가 조금 낡는 것보다
  /// 화면이 멈춘 것이 나쁘다.
  static const _timeout = Duration(seconds: 3);

  /// 화면에 띄울 약관을 고른다.
  ///
  /// 캐시가 있으면 **기다리지 않는다.** 즉시 캐시를 주고 갱신은 뒤에서 돈다 —
  /// 재동의로 다시 들어온 사람을 매번 3초씩 세울 이유가 없다.
  /// 캐시가 없을 때(=첫 실행)만 서버를 기다린다. 그때 기다리지 않으면 관리자가
  /// 고친 문구가 **정작 신규 가입자에게 안 간다.**
  Future<ConsentBundle> load() async {
    final cached = _readCache();
    if (cached != null) {
      // 실패해도 무시한다 — 결과는 다음에 열 때 쓰인다.
      unawaited(fetchAndCache());
      return cached;
    }
    return await fetchAndCache() ?? ConsentBundle.bundled;
  }

  /// 서버에서 받아 캐시에 넣는다. 실패하면 null이고 **예외를 던지지 않는다.**
  Future<ConsentBundle?> fetchAndCache() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/consents/documents',
        // 인증 없이 열린 경로다. 토큰이 있으면 붙지만 서버가 보지 않는다.
        options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
      );
      final bundle = ConsentBundle.tryParse(
        response.data,
        source: ConsentSource.server,
      );
      if (bundle == null) {
        AppLogger.error('약관 조회', '응답 형식이 달라 무시합니다');
        return null;
      }
      await _writeCache(bundle);
      return bundle;
    } catch (e) {
      // 서버를 못 봤다. 화면은 캐시나 번들 기본값으로 그대로 뜬다.
      AppLogger.error('약관 조회', e);
      return null;
    }
  }

  ConsentBundle? _readCache() {
    try {
      final json = _storage.cachedConsentJson;
      if (json == null || json.isEmpty) return null;
      return ConsentBundle.tryParseJson(json, source: ConsentSource.cache);
    } catch (e) {
      // 사생활 보호 모드 등에서 저장소 접근 자체가 막힐 수 있다.
      AppLogger.error('약관 캐시 읽기', e);
      return null;
    }
  }

  Future<void> _writeCache(ConsentBundle bundle) async {
    try {
      await _storage.setCachedConsentJson(bundle.toJson());
    } catch (e) {
      // 캐시에 못 넣어도 이번 화면은 멀쩡히 뜬다. 다음에 또 받으면 된다.
      AppLogger.error('약관 캐시 쓰기', e);
    }
  }
}

final consentDocumentRepositoryProvider = Provider<ConsentDocumentRepository>((ref) {
  return ConsentDocumentRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  );
});

/// 동의 화면이 읽는다. 실패하지 않는다 — 최악의 경우 앱 번들 기본값이 온다.
final consentBundleProvider = FutureProvider<ConsentBundle>((ref) {
  return ref.watch(consentDocumentRepositoryProvider).load();
});

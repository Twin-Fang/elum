import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/dio_client.dart';
import '../domain/ad_reward.dart';

/// 보호자가 광고를 보고 크레딧을 받는 서버 API (#463).
///
/// **"광고를 봤다"고 알리는 API 는 없다.** 지급은 Google 이 서버로 보내는 SSV 콜백이
/// 정한다. 앱은 세션을 만들고(nonce 발급), 광고에 nonce 를 실어 보여 준 뒤, 서버가
/// 지급했는지 상태를 묻기만 한다.
///
/// 실패는 [AppFailure] 로 던진다 — 호출한 쪽이 코드를 보이는 안내로 바꾼다.
/// nonce 는 한 번용 비밀에 가까워 로그에 남기지 않는다.
class AdRewardRepository {
  AdRewardRepository(this._dio);

  final Dio _dio;

  static const _base = '/api/credits/ad-rewards';

  Future<AdRewardOffer> getOffer() => _call(
    'getOffer',
    () async => AdRewardOffer.fromJson(await _get('$_base/offer')),
  );

  Future<AdRewardSession> createSession() => _call('createSession', () async {
    final res = await _dio.post<Map<String, dynamic>>('$_base/sessions');
    return AdRewardSession.fromJson(_body(res));
  });

  Future<AdRewardSessionStatus> getStatus(String nonce) => _call(
    'getStatus',
    () async => AdRewardSessionStatus.fromJson(
      await _get('$_base/sessions/${Uri.encodeComponent(nonce)}'),
    ),
  );

  Future<Map<String, dynamic>> _get(String path) async =>
      _body(await _dio.get<Map<String, dynamic>>(path));

  Map<String, dynamic> _body(Response<Map<String, dynamic>> res) {
    final body = res.data;
    if (body == null) throw const FormatException('빈 응답');
    return body;
  }

  Future<T> _call<T>(String name, Future<T> Function() run) async {
    AppLogger.repositoryCall('AdRewardRepository', name);
    try {
      return await run();
    } catch (e) {
      AppLogger.repositoryError('AdRewardRepository', name, e);
      throw AppFailure.of(e);
    }
  }
}

final adRewardRepositoryProvider = Provider<AdRewardRepository>(
  (ref) => AdRewardRepository(ref.watch(dioProvider)),
);

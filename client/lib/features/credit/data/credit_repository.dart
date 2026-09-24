import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/dio_client.dart';
import '../domain/credit_summary.dart';

/// AI 크레딧 조회 (#407).
///
/// **실패를 0 으로 바꾸지 않는다.** 일과 저장소는 실패를 흡수하지만 여기는 다르다 —
/// 잔액을 모르는데 0 을 그리면 보호자는 다 썼다고 믿고 만들기를 포기한다.
/// 그래서 무엇이 안 됐든 [AppFailure] 로 던지고, 화면이 `다시 하기`와 코드를 띄운다.
class CreditRepository {
  CreditRepository(this._dio);

  final Dio _dio;

  Future<CreditSummary> getMine() async {
    AppLogger.repositoryCall('CreditRepository', 'getMine');
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/credits/me');
      final body = res.data;
      if (body == null) throw const FormatException('빈 응답');
      final summary = CreditSummary.fromJson(body);
      AppLogger.repositorySuccess(
        'CreditRepository',
        'getMine',
        summary.enabled ? '남음 ${summary.available}' : '꺼짐',
      );
      return summary;
    } catch (e) {
      AppLogger.repositoryError('CreditRepository', 'getMine', e);
      throw AppFailure.of(e);
    }
  }
}

final creditRepositoryProvider = Provider<CreditRepository>(
  (ref) => CreditRepository(ref.watch(dioProvider)),
);

/// 설정 카드·직전 안내가 보는 요약. 화면을 떠나면 버린다 — 다음에 열 때 새로 받는다.
///
/// 생성이 끝나거나 실패하면 흐름이 invalidate 한다. 잔액이 바뀐 뒤 옛 숫자를 보여주면
/// 방금 쓴 크레딧이 안 줄어든 것처럼 보인다.
///
/// 저절로 다시 시도하지 않는다(`retry`). 실패는 화면이 `다시 하기`로 보여 주는데,
/// 뒤에서 몰래 재시도하면 실패 화면이 로딩으로 깜빡이고 요청이 쌓인다.
final creditSummaryProvider = FutureProvider.autoDispose<CreditSummary>(
  (ref) => ref.watch(creditRepositoryProvider).getMine(),
  retry: (_, _) => null,
);

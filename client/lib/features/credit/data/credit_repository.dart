import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/guarded_call.dart';
import '../../../core/network/app_failure.dart';
import '../domain/credit_history.dart';
import '../domain/credit_summary.dart';
import '../../../app/dio_provider.dart';

/// AI 크레딧 조회.
///
/// **실패를 0 으로 바꾸지 않는다.** 일과 저장소는 실패를 흡수하지만 여기는 다르다 —
/// 잔액을 모르는데 0 을 그리면 보호자는 다 썼다고 믿고 만들기를 포기한다.
/// 그래서 무엇이 안 됐든 [AppFailure] 로 던지고, 화면이 `다시 하기`와 코드를 띄운다.
class CreditRepository {
  CreditRepository(this._dio);

  final Dio _dio;

  /// 한 번에 받는 줄 수. 서버 기본값(30)과 같다.
  static const historyPageSize = 30;

  Future<CreditSummary> getMine() async {
    try {
      return await logged(
        'CreditRepository',
        'getMine',
        () async {
          final res = await _dio.get<Map<String, dynamic>>('/api/credits/me');
          final body = res.data;
          if (body == null) throw const FormatException('빈 응답');
          return CreditSummary.fromJson(body);
        },
        describe: (s) => s.enabled ? '남음 ${s.available}' : '꺼짐', // l10n-ignore: 로그 요약
      );
    } catch (e) {
      // 화면이 실패 유형을 알 수 있게 AppFailure 로 통일해 던진다
      throw AppFailure.of(e);
    }
  }

  /// 사용 내역 한 쪽 (최근 것부터). 실패는 [AppFailure] 로 던진다 — 빈 목록으로 바꾸지 않는다.
  Future<CreditHistoryPage> getHistory({required int page, int size = historyPageSize}) async {
    try {
      return await logged(
        'CreditRepository',
        'getHistory',
        () async {
          final res = await _dio.get<Map<String, dynamic>>(
            '/api/credits/ledger',
            queryParameters: {'page': page, 'size': size},
          );
          final body = res.data;
          if (body == null) throw const FormatException('빈 응답');
          return CreditHistoryPage.fromJson(body);
        },
        describe: (p) => '${p.entries.length}건 ${p.hasNext ? '다음 있음' : '끝'}', // l10n-ignore: 로그 요약
      );
    } catch (e) {
      throw AppFailure.of(e);
    }
  }
}

final creditRepositoryProvider = Provider<CreditRepository>(
  (ref) => CreditRepository(ref.watch(dioProvider)),
);

/// 설정 카드·직전 안내가 보는 요약. 화면을 떠나면 버린다 — 다음에 열 때 새로 받는다.
///
/// 생성이 끝나거나 실패하면 흐름이 invalidate 한다. 잔액이 바뀐 뒤 이전 숫자를 보여주면
/// 방금 쓴 크레딧이 안 줄어든 것처럼 보인다.
///
/// 저절로 다시 시도하지 않는다(`retry`). 실패는 화면이 `다시 하기`로 보여 주는데,
/// 뒤에서 몰래 재시도하면 실패 화면이 로딩으로 깜빡이고 요청이 쌓인다.
final creditSummaryProvider = FutureProvider.autoDispose<CreditSummary>(
  (ref) => ref.watch(creditRepositoryProvider).getMine(),
  retry: (_, _) => null,
);

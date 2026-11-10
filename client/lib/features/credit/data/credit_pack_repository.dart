import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../domain/credit_pack.dart';
import '../domain/credit_purchase.dart';

/// 크레딧 꾸러미 목록 · 구매 확인 API (소모성 상품)
///
/// 예외를 올리지 않고 [Attempt] 로 돌려줌. 구매 확인 응답 모양이 다르면 실패 (거래를 마무리하지 않게).
/// 증빙 원문(JWS · 구매 토큰)은 로그에 남기지 않음
class CreditPackRepository {
  CreditPackRepository(this._dio);

  final Dio _dio;

  static const _repo = 'CreditPackRepository';

  /// 판매 스위치 + 꾸러미 (상품 id · 개수 · 인기)
  Future<Attempt<CreditPackSale>> fetchPackSale() => guarded(_repo, 'fetchPackSale', () async {
    final response = await _dio.get<Map<String, dynamic>>('/api/credits/packs');
    return CreditPackSale.parse(response.data);
  }, describe: (sale) => 'packs ${sale.packs.length} sale ${sale.isSaleEnabled}');

  /// App Store: `Transaction.jwsRepresentation`
  Future<Attempt<CreditPurchaseResult>> verifyApple(String signedTransaction) =>
      guarded(_repo, 'verifyApple', () async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/credits/purchases/apple',
          data: {'signedTransaction': signedTransaction},
        );
        return _parse(response.data);
      }, describe: (result) => result.status.wire);

  /// Google Play: 상품 id + 구매 토큰
  Future<Attempt<CreditPurchaseResult>> verifyGoogle({
    required String productId,
    required String purchaseToken,
  }) => guarded(_repo, 'verifyGoogle', () async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/credits/purchases/google',
      data: {'productId': productId, 'purchaseToken': purchaseToken},
    );
    return _parse(response.data);
  }, describe: (result) => result.status.wire);

  static CreditPurchaseResult _parse(Map<String, dynamic>? body) {
    final status = CreditPurchaseStatus.tryParse(body?['status']);
    if (status == null) throw const FormatException('credit purchase status is missing or unknown');
    final granted = body?['grantedCredits'];
    final available = body?['available'];
    return CreditPurchaseResult(
      status: status,
      grantedCredits: granted is num ? granted.toInt() : 0,
      available: available is num ? available.toInt() : null,
    );
  }
}

final creditPackRepositoryProvider = Provider<CreditPackRepository>(
  (ref) => CreditPackRepository(ref.watch(dioProvider)),
);

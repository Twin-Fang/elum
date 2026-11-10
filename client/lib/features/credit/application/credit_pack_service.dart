import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/credit_pack_repository.dart';
import '../domain/credit_pack.dart';
import '../domain/credit_purchase.dart';

/// 크레딧 꾸러미 목록 · 구매 확인 (스토어 결제를 맡는 subscription 응용 계층이 부르는 입구)
class CreditPackService {
  CreditPackService(this._repository);

  final CreditPackRepository _repository;

  Future<Attempt<CreditPackSale>> fetchPackSale() => _repository.fetchPackSale();

  Future<Attempt<CreditPurchaseResult>> verifyApple(String signedTransaction) =>
      _repository.verifyApple(signedTransaction);

  Future<Attempt<CreditPurchaseResult>> verifyGoogle({required String productId, required String purchaseToken}) =>
      _repository.verifyGoogle(productId: productId, purchaseToken: purchaseToken);
}

final creditPackServiceProvider = Provider<CreditPackService>(
  (ref) => CreditPackService(ref.watch(creditPackRepositoryProvider)),
);

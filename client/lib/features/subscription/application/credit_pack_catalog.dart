import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dev/dev_plan_override.dart';
import '../../../core/logger/app_logger.dart';
import '../../credit/application/credit_pack_service.dart';
import '../../credit/domain/credit_pack.dart';
import '../data/store_billing_client.dart';
import 'plan_store_catalog.dart';

/// 스토어 상품 조회 최대 대기 (스토어 앱이 응답하지 않을 때 무한 로딩 방지)
const _priceTimeout = Duration(seconds: 15);

/// 화면이 그릴 꾸러미 칸들 (개수 적은 순). 빈 목록이면 구역을 통째로 숨김
///
/// 판매 조건 3개: 서버 판매 스위치 켜짐 + 스토어 연결 + 상품 값 불러옴 (구독 판매 판정과 별개).
/// 서버 목록을 못 받으면 구역을 숨기고 로그만 남김. 스토어 값을 못 받으면 예외 > 구역 자리가 `E-CREDIT-PACK-PRICE` + 다시 하기
final creditPackOffersProvider = FutureProvider.autoDispose<List<CreditPackOffer>>((ref) async {
  // 개발자 도구 `크레딧 판매 화면 켜기`: 서버 판매 스위치·스토어 연결과 무관하게 구역을 보임 (값이 없으면 값 오류 상태)
  final isForced = ref.watch(devCreditPackSaleForcedProvider);
  if (!isForced && !ref.watch(isPlanStoreConnectedProvider)) return const [];
  final attempt = await ref.watch(creditPackServiceProvider).fetchPackSale();
  final sale = attempt.value;
  if (sale == null) {
    AppLogger.info('[credit pack] list failed : section hidden');
    if (isForced) throw const StoreCatalogException('list');
    return const [];
  }
  if (isForced && sale.packs.isEmpty) throw const StoreCatalogException('empty');
  if (!isForced && !sale.hasPacksToSell) return const [];
  final prices = await ref
      .watch(storeBillingClientProvider)
      .loadConsumablePrices({for (final pack in sale.packs) pack.productId})
      .timeout(_priceTimeout, onTimeout: () => throw const StoreCatalogException('timeout'));
  return buildCreditPackOffers(sale.packs, prices);
}, retry: (_, _) => null);

/// 지금 꾸러미를 살 수 있는가 (불러온 칸이 있음). 부족 팝업의 `크레딧 더 받기` 가 봄
final canPurchaseCreditPacksProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(creditPackOffersProvider).value?.isNotEmpty ?? false,
);

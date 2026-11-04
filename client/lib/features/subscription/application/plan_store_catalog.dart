import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/dev/dev_plan_override.dart';
import '../../../core/storage/local_storage.dart';
import '../data/store_billing_client.dart';
import '../domain/plan_catalog.dart';

/// 스토어 상품 조회 최대 대기 (스토어 앱이 응답하지 않을 때 무한 로딩 방지)
const _catalogTimeout = Duration(seconds: 15);

/// 이 기기에서 Pro 를 팔아도 되는가: 판매 스위치(빌드 설정 · 개발자 도구) + 보호자 기기
///
/// 이룸이 기기는 어떤 경우에도 결제·Pro 안내를 두지 않는다
final isPlanStoreEnabledProvider = Provider<bool>((ref) {
  if (ref.watch(localStorageProvider).isElumiDevice) return false;
  return AppConfig.isInAppPurchaseEnabled || ref.watch(devPlanStoreForcedProvider);
});

/// 요금제 화면 상품·가격: 스토어 연결 > 상품 조회 (기간별 1개). 실패하면 에러 상태 (`E-PLAN-PRICE` + 다시 시도)
final planCatalogProvider = FutureProvider<PlanCatalog>((ref) {
  if (!ref.watch(isPlanStoreEnabledProvider)) {
    throw const StoreCatalogException('disabled');
  }
  return ref
      .watch(storeBillingClientProvider)
      .loadCatalog({
        PlanPeriod.monthly: AppConfig.iapProductMonthly,
        PlanPeriod.yearly: AppConfig.iapProductYearly,
      })
      .timeout(
        _catalogTimeout,
        onTimeout: () => throw const StoreCatalogException('timeout'),
      );
}, retry: (_, _) => null);

/// 앱에서 Pro 를 살 수 있는가: 판매 스위치 켜짐 + 스토어 연결됨 + 상품 불러옴
///
/// Pro 전용 선택지·`Pro 알아보기` 는 이 값이 true 일 때만 보인다 (살 방법이 없는데 잠금만 보이지 않게)
final canPurchaseProProvider = Provider<bool>((ref) {
  // 개발자 도구 `Pro 미리 보기 켜기` (이룸이 기기는 제외)
  if (ref.watch(devProTeaserForcedProvider) && !ref.watch(localStorageProvider).isElumiDevice) return true;
  if (!ref.watch(isPlanStoreEnabledProvider)) return false;
  return ref.watch(planCatalogProvider).value?.hasOffers ?? false;
});

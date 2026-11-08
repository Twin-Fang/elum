import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_status/store_selling.dart';
import '../../../core/config/app_config.dart';
import '../../../core/dev/dev_plan_override.dart';
import '../../../core/storage/local_storage.dart';
import '../data/store_billing_client.dart';
import '../domain/plan_catalog.dart';

/// 스토어 상품 조회 최대 대기 (스토어 앱이 응답하지 않을 때 무한 로딩 방지)
const _catalogTimeout = Duration(seconds: 15);

/// 이 기기에 스토어 결제 연동이 있는가: 보호자 기기 + 빌드 설정(하드 킬) · 개발자 도구
///
/// 구매 소식 듣기·구매 복원·구독 관리 기준. 서버 판매 스위치와 무관 (판매를 멈춰도 기존 구독은 유지, #1132)
/// 이룸이 기기는 어떤 경우에도 결제·Pro 안내를 두지 않는다
final isPlanStoreConnectedProvider = Provider<bool>((ref) {
  if (ref.watch(localStorageProvider).isElumiDevice) return false;
  return AppConfig.isInAppPurchaseEnabled || ref.watch(devPlanStoreForcedProvider);
});

/// 이 기기에서 Pro 를 새로 팔아도 되는가: 스토어 연동 + 서버 판매 스위치(지금 플랫폼, #1132) · 개발자 도구 강제 켜기
///
/// 빌드 설정이 꺼져 있으면 서버 값과 무관하게 팔지 않음. 요금제 화면·`Pro 알아보기`·상품 조회 기준
final isPlanStoreEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(isPlanStoreConnectedProvider)) return false;
  if (ref.watch(devPlanStoreForcedProvider)) return true;
  return ref.watch(isServerStoreSellingOpenProvider);
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

/// 앱에서 Pro 를 살 수 있는가: 판매 중 + 스토어 연결됨 + 상품 불러옴
///
/// Pro 전용 선택지·`Pro 알아보기` 는 이 값이 true 일 때만 보인다 (살 방법이 없는데 잠금만 보이지 않게)
final canPurchaseProProvider = Provider<bool>((ref) {
  // 개발자 도구 `Pro 미리 보기 켜기` (이룸이 기기는 제외)
  if (ref.watch(devProTeaserForcedProvider) && !ref.watch(localStorageProvider).isElumiDevice) return true;
  if (!ref.watch(isPlanStoreEnabledProvider)) return false;
  return ref.watch(planCatalogProvider).value?.hasOffers ?? false;
});

/// Pro 권유 버튼의 체험: 처음 고르는 상품(1년)에 스토어가 체험을 준다고 알렸을 때만 (#1166). 상품 모름·체험 없음 > null
final proUpsellFreeTrialProvider = Provider<PlanFreeTrial?>(
  (ref) => ref.watch(planCatalogProvider).value?.recommendedOffer?.freeTrial,
);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../subscription/application/credit_purchase_notifier.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/application/plan_store_catalog.dart';
import '../../application/credit_cost_guide_entry.dart';
import '../../domain/credit_summary.dart';

/// 내 크레딧 맨 아래 보조 동작 묶음: 사용 내역 > 쓰는 법 > (스토어 연결 시) 프로모션 코드 입력 > 구매 복원
/// 꾸러미 결제 중이면 줄을 모두 막음. 코드 입력·복원은 판매 스위치와 무관 (#1132)
class MyCreditMenuGroup extends ConsumerWidget {
  const MyCreditMenuGroup({super.key, required this.summary});

  /// 쓰는 법 창의 단가·지급량 기준
  final CreditSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isBusy = ref.watch(creditPurchaseStateProvider.select((state) => state.isBusy));
    final isStoreConnected = ref.watch(isPlanStoreConnectedProvider);
    VoidCallback? unlessBusy(VoidCallback onTap) => isBusy ? null : onTap;
    return SettingsGroup(
      children: [
        SettingsTile(
          isInCard: true,
          label: l10n.creditHistoryTitle,
          onTap: unlessBusy(() => context.push(Routes.guardianCreditHistory)),
        ),
        SettingsTile(
          isInCard: true,
          label: l10n.myCreditGuideLink,
          onTap: unlessBusy(() => showCreditCostGuide(context, ref, summary)),
        ),
        if (isStoreConnected) ...[
          SettingsTile(
            isInCard: true,
            label: l10n.planRedeemCode,
            onTap: unlessBusy(() => openStoreCodeRedemption(context, ref)),
          ),
          SettingsTile(
            isInCard: true,
            label: l10n.planRestore,
            onTap: unlessBusy(() => restorePlanPurchases(context, ref)),
          ),
        ],
      ],
    );
  }
}

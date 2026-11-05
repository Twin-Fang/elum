import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/application/plan_status_providers.dart';
import '../../../subscription/application/plan_store_catalog.dart';

/// 설정 맨 위 요금제 묶음: `내 요금제` 줄(Free · Pro) + `구매 복원` > 아래 한 줄(갱신일 · 해지 예약 · 결제 확인 필요)
///
/// 요금제 화면을 열 수 없으면(판매 중 아님 + Pro 아님) 상태만 보임. 구매 복원은 스토어 연동이면 판매와 무관하게 보임 (#1132)
class PlanSettingsGroup extends ConsumerWidget {
  const PlanSettingsGroup({super.key, required this.isBusy});

  /// 설정 화면이 다른 동작(로그아웃 등) 중이면 줄을 막음
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final canOpenPaywall = ref.watch(canOpenPlanPaywallProvider);
    final isStoreConnected = ref.watch(isPlanStoreConnectedProvider);
    final status = ref.watch(planStatusProvider);
    return SettingsGroup(
      footer: planStatusFooter(l10n, status),
      children: [
        SettingsTile(
          isInCard: true,
          label: l10n.planSettingsLabel,
          valueText: planStatusShortLabel(l10n, status),
          showChevronWithValue: canOpenPaywall,
          onTap: isBusy || !canOpenPaywall ? null : () => openPlanPaywall(context, ref),
        ),
        if (isStoreConnected)
          SettingsTile(
            isInCard: true,
            label: l10n.planRestore,
            onTap: isBusy ? null : () => restorePlanPurchases(context, ref),
          ),
      ],
    );
  }
}

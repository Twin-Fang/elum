import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/application/plan_status_providers.dart';
import '../../../subscription/application/plan_store_catalog.dart';

/// 설정 맨 위 요금제 묶음: `내 요금제` 줄(Free · Pro 갱신일 · 해지 예약 · 결제 확인 필요) + `구매 복원`
///
/// 판매 스위치가 꺼져 있으면 상태만 보이고 누를 곳이 없음 (살 방법이 없는데 결제 화면을 열지 않음)
class PlanSettingsGroup extends ConsumerWidget {
  const PlanSettingsGroup({super.key, required this.isBusy});

  /// 설정 화면이 다른 동작(로그아웃 등) 중이면 줄을 막음
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isStoreEnabled = ref.watch(isPlanStoreEnabledProvider);
    final status = ref.watch(planStatusProvider);
    return SettingsGroup(
      children: [
        SettingsTile(
          isInCard: true,
          label: l10n.planSettingsLabel,
          valueText: planStatusLabel(l10n, status),
          showChevronWithValue: isStoreEnabled,
          onTap: isBusy || !isStoreEnabled ? null : () => openPlanPaywall(context, ref),
        ),
        if (isStoreEnabled)
          SettingsTile(
            isInCard: true,
            label: l10n.planRestore,
            onTap: isBusy ? null : () => restorePlanPurchases(context, ref),
          ),
      ],
    );
  }
}

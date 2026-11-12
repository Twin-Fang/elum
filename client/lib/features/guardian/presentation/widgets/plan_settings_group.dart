import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../subscription/application/plan_paywall_entry.dart';
import '../../../subscription/application/plan_status_providers.dart';
import '../../../subscription/application/plan_store_catalog.dart';

/// 설정 맨 위 요금제 묶음: `내 요금제` 줄(Free · Pro) + `내 크레딧` + `구매 복원` > 아래 한 줄(갱신일 · 해지 예약 · 결제 확인 필요)
///
/// `내 요금제` 줄: Pro > 내 요금제 시트(날짜 · 결제한 곳 · 구독 관리, #1303), Free > 요금제 화면. Free 인데 판매 중 아니면 상태만 보임. 구매 복원은 스토어 연동이면 판매와 무관하게 보임 (#1132)
class PlanSettingsGroup extends ConsumerWidget {
  const PlanSettingsGroup({super.key, required this.isBusy});

  /// 설정 화면이 다른 동작(로그아웃 등) 중이면 줄을 막음
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(planStatusProvider);
    // Pro 는 늘 내 요금제 시트 (판매와 무관), Free 는 요금제 화면을 열 수 있을 때만 누름
    final canOpenMyPlan = status.isPro || ref.watch(canOpenPlanPaywallProvider);
    final isStoreConnected = ref.watch(isPlanStoreConnectedProvider);
    return SettingsGroup(
      footer: planStatusFooter(l10n, status),
      children: [
        SettingsTile(
          isInCard: true,
          label: l10n.planSettingsLabel,
          // 글자보다 모양으로 Free · Pro 차이를 보여 줌 (읽기 프로그램은 값 글자를 읽음)
          valueText: planStatusShortLabel(l10n, status),
          valueChip: PlanTierChip(tier: planTierOf(status)),
          showChevronWithValue: canOpenMyPlan,
          onTap: isBusy || !canOpenMyPlan ? null : () => openMyPlan(context, ref),
        ),
        SettingsTile(
          isInCard: true,
          label: l10n.myCreditTitle,
          onTap: isBusy ? null : () => context.push(Routes.guardianMyCredit),
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

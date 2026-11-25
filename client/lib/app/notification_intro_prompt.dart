import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/assets/app_assets.dart';
import '../core/l10n/l10n_context.dart';
import '../core/layout/layout_context_ext.dart';
import '../core/layout/window_size_class.dart';
import '../core/widgets/elum_guide_panel.dart';
import '../core/widgets/elum_secondary_button.dart';
import '../features/credit/application/credit_costs.dart';
import '../features/member/application/plan_access.dart';
import '../features/notification/application/device_notification_permission_controller.dart';
import '../features/notification/application/push_permission_prompt.dart';

/// 알림 켜기 안내 (홈·공지 런처가 함께 써서 app 층): 폰은 아래 시트, 태블릿은 가운데 창 > `알림 켜기`(시스템 권한 창 · 거부 상태면 설정 안내 > 기기 설정) · `나중에` (#1455)
/// 띄운 순간 본 기록 (다시 안 띄움, 7일 다시 권하기와 겹치지 않게). 끝나면(어느 버튼이든) 돌아옴
Future<void> showNotificationIntroPrompt(BuildContext context, WidgetRef ref) async {
  // 본 기록은 띄우면서 남김 (저장 실패해도 안내는 띄움, 기록 쪽이 로그)
  unawaited(ref.read(pushPermissionPromptProvider).markIntroShown());
  final isPhone = context.sizeClass == WindowSizeClass.compact;
  final placement = isPhone ? ElumGuidePlacement.sheet : ElumGuidePlacement.dialog;
  Widget panelOf(BuildContext promptContext) => _NotificationIntroPanel(placement: placement);
  final Future<bool?> promptClosed = isPhone
      ? showElumGuideSheet<bool>(context: context, builder: panelOf)
      : showElumGuideDialog<bool>(context: context, builder: panelOf, barrierDismissible: true);
  final isTurnOnChosen = await promptClosed;
  if (isTurnOnChosen != true || !context.mounted) return;
  await ref.read(deviceNotificationPermissionControllerProvider.notifier).turnOn(context);
}

/// 그림 > 제목 > 이유 한 줄 > 받는 알림 3줄 > 알림 켜기 · 나중에
class _NotificationIntroPanel extends ConsumerWidget {
  const _NotificationIntroPanel({required this.placement});

  final ElumGuidePlacement placement;

  /// 셋째 줄: 주간 리포트 권한 있으면 리포트, 없으면 크레딧 다시 채워짐 (주·달 단위)
  String _thirdRowTitle(WidgetRef ref, AppLocalizations l10n) {
    if (ref.watch(planAccessProvider).canViewWeeklyReport) return l10n.notificationIntroWeeklyReport;
    return ref.watch(creditPeriodUnitProvider).notificationIntroCreditRefilled(l10n);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final illustrationSize = placement == ElumGuidePlacement.sheet
        ? ElumGuideIllustrationSize.sheet
        : ElumGuideIllustrationSize.dialog;
    return ElumGuidePanel(
      placement: placement,
      illustration: ElumGuideIllustration(asset: AppAssets.homeNoticeBell, size: illustrationSize),
      title: l10n.notificationIntroTitle,
      description: l10n.notificationIntroBody,
      // 받는 알림 3개
      content: [
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: l10n.notificationIntroRoutineDone),
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: l10n.notificationIntroCaregiverRoutine),
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: _thirdRowTitle(ref, l10n)),
      ],
      primaryAction: ElumGuideAction(
        label: l10n.pushPermissionTurnOn,
        onTap: () => Navigator.of(context).pop(true),
      ),
      secondaryActions: [
        ElumSecondaryButton(label: l10n.pushPermissionLater, onTap: () => Navigator.of(context).pop(false)),
      ],
    );
  }
}

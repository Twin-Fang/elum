import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/assets/app_assets.dart';
import '../core/l10n/l10n_context.dart';
import '../core/router/routes.dart';
import '../core/widgets/home_notice_card.dart';
import 'home_auto_send_upsell.dart';

/// 보호자 홈 자동 보내기 안내 카드 (#1284): 일과를 3개 이상 만든 Free 보호자에게 한 번
/// 누르면 주간 계획 화면(반복 일과 Pro 미리 보기)으로. 누르거나 닫으면 다시 안 보임
class HomeAutoSendUpsellCard extends ConsumerWidget {
  const HomeAutoSendUpsellCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final record = ref.read(homeAutoSendUpsellRecordProvider.notifier);
    return HomeNoticeCard(
      title: l10n.homeAutoSendUpsellTitle,
      body: l10n.homeAutoSendUpsellBody,
      actionLabel: l10n.homeAutoSendUpsellAction,
      tileAsset: AppAssets.homeNoticeAutoSend,
      // 이동을 먼저 시작 (닫기로 카드가 접혀도 이동은 그대로)
      onAction: () async {
        final navigation = context.push<void>(Routes.guardianWeeklyPlan);
        await record.close();
        await navigation;
      },
      onDismiss: record.close,
      dismissLabel: l10n.homeSuggestionDismissLabel,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/assets/app_assets.dart';
import '../core/l10n/l10n_context.dart';
import '../core/widgets/home_notice_card.dart';
import '../features/credit/application/credit_top_up_entry.dart';
import '../features/credit/application/low_credit_notice.dart';

/// 보호자 홈 크레딧 부족 카드: 조건은 [lowCreditNoticeProvider], 보일지는 [homeNoticeChoiceProvider]
///
/// 누르면 광고를 바로 띄움 (받은 뒤 잔액이 넉넉해지면 저절로 사라짐). 닫으면 이번 크레딧 주기에는 안 보임
class LowCreditNoticeCard extends ConsumerWidget {
  const LowCreditNoticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(lowCreditNoticeProvider);
    if (notice == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return HomeNoticeCard(
      title: notice.available <= 0 ? l10n.lowCreditNoticeTitleEmpty : l10n.lowCreditNoticeTitle,
      body: l10n.lowCreditNoticeBody,
      actionLabel: l10n.lowCreditNoticeAction,
      tileAsset: AppAssets.creditLowLumi,
      onAction: () => watchAdForCredits(context, ref),
      onDismiss: () => ref.read(lowCreditNoticeDismissalProvider.notifier).dismiss(notice.period),
      dismissLabel: l10n.commonClose,
    );
  }
}

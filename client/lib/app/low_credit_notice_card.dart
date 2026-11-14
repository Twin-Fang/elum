import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/assets/app_assets.dart';
import '../core/l10n/l10n_context.dart';
import '../core/widgets/elum_info_card.dart';
import '../features/credit/application/credit_top_up_entry.dart';
import '../features/credit/application/low_credit_notice.dart';

/// 보호자 홈 크레딧 부족 카드 (작은 안내 카드, 3D 재생 그림): 조건은 [lowCreditNoticeProvider], 보일지는 [homeNoticeChoiceProvider]
///
/// 광고를 미리 불러 둔 뒤에만 보임 > 누르면 바로 광고 (받은 뒤 잔액이 넉넉해지면 저절로 사라짐). 닫으면 이번 크레딧 주기에는 안 보임
class LowCreditNoticeCard extends ConsumerWidget {
  const LowCreditNoticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(lowCreditNoticeProvider);
    if (notice == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ElumInfoCard(
      illustrationAsset: AppAssets.featureIconAdPlay,
      title: notice.available <= 0 ? l10n.lowCreditNoticeTitleEmpty : l10n.lowCreditNoticeTitle,
      body: l10n.lowCreditNoticeBody,
      actionLabel: l10n.lowCreditNoticeAction,
      onAction: () => watchAdForCredits(context, ref),
      onClose: () => ref.read(lowCreditNoticeDismissalProvider.notifier).dismiss(notice.period),
      closeLabel: l10n.commonClose,
    );
  }
}

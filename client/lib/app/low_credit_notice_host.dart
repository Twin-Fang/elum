import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/assets/app_assets.dart';
import '../core/haptics/tap_haptics.dart';
import '../core/l10n/l10n_context.dart';
import '../core/theme/app_motion.dart';
import '../core/widgets/app_fade_slide_in.dart';
import '../core/widgets/home_notice_card.dart';
import '../features/credit/application/credit_top_up_entry.dart';
import '../features/credit/application/low_credit_notice.dart';
import '../features/notification/application/device_notification_permission_controller.dart';
import '../features/notification/application/home_notification_notice_provider.dart';

/// 보호자 홈의 크레딧 부족 카드 자리: 조건이 맞을 때만 보임 ([lowCreditNoticeProvider])
///
/// 누르면 광고를 바로 띄움 (받은 뒤 잔액이 넉넉해지면 저절로 사라짐). 닫으면 이번 크레딧 주기에는 안 보임.
/// 나타날 때 아래에서 살짝 올라오고, 사라질 때 접힘 (동작 줄이기면 바로)
class LowCreditNoticeHost extends ConsumerWidget {
  const LowCreditNoticeHost({super.key, required this.bottomGap});

  /// 카드 아래 간격 (카드가 보일 때만)
  final double bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 홈 안내 카드는 한 번에 하나: 알림 꺼짐 카드가 먼저
    final isNotificationNoticeVisible =
        ref.watch(deviceNotificationPermissionControllerProvider) && !ref.watch(homeNotificationNoticeDismissalProvider);
    final notice = isNotificationNoticeVisible ? null : ref.watch(lowCreditNoticeProvider);
    final isReducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: isReducedMotion ? Duration.zero : AppMotion.normal,
      switchInCurve: AppMotion.entry,
      switchOutCurve: AppMotion.standard,
      // 접히며 사라짐 (높이 > 0 · 흐려짐)
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: notice == null ? const SizedBox.shrink() : _card(context, ref, notice),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, LowCreditNotice notice) {
    final l10n = context.l10n;
    return AppFadeSlideIn(
      key: ValueKey(notice.period),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomGap.h),
        child: HomeNoticeCard(
          title: notice.available <= 0 ? l10n.lowCreditNoticeTitleEmpty : l10n.lowCreditNoticeTitle,
          body: l10n.lowCreditNoticeBody,
          actionLabel: l10n.lowCreditNoticeAction,
          tileAsset: AppAssets.creditLowLumi,
          actionIconAsset: AppAssets.iconPlay,
          onAction: () {
            playTapHaptic();
            watchAdForCredits(context, ref);
          },
          onDismiss: () {
            playTapHaptic();
            ref.read(lowCreditNoticeDismissalProvider.notifier).dismiss(notice.period);
          },
          dismissLabel: l10n.commonClose,
        ),
      ),
    );
  }
}

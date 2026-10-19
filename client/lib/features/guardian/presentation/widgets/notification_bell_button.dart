import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/periodic_refresh.dart';
import '../../../notification/application/unread_summary_provider.dart';

/// 홈 머리 줄의 종 아이콘: 안 읽은 알림·공지가 있으면 빨간 점, 탭하면 알림 화면
///
/// 앱이 앞으로 돌아올 때마다 요약을 다시 받음 (주기 갱신은 길게)
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  /// 아이콘 28 · 누르는 영역 44 · 점 지름 8
  static const _iconSize = 28.0;
  static const _tapSize = 44.0;
  static const _dotSize = 8.0;

  /// 앱이 켜져 있는 동안 도는 갱신 주기 (푸시 수신 갱신은 #828)
  static const _refreshInterval = Duration(minutes: 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(unreadSummaryProvider).value;
    final hasUnread = summary != null &&
        (summary.hasUnreadNotification || summary.hasUnreadNotice);
    final l10n = context.l10n;
    final label = hasUnread
        ? '${l10n.notificationBellLabel}, ${l10n.notificationBellUnreadLabel}'
        : l10n.notificationBellLabel;

    return PeriodicRefresh(
      interval: _refreshInterval,
      onRefresh: () => ref.read(unreadSummaryProvider.notifier).refresh(),
      child: AppPressable(
        onTap: () => _openNotifications(context, ref),
        scaleDown: AppPressable.scaleIcon,
        semanticLabel: label,
        child: SizedBox(
          width: _tapSize.w,
          height: _tapSize.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                AppAssets.notificationBell,
                width: _iconSize.w,
                height: _iconSize.w,
              ),
              if (hasUnread)
                Positioned(
                  top: ((_tapSize - _iconSize) / 2).w,
                  right: ((_tapSize - _iconSize) / 2).w,
                  child: Container(
                    width: _dotSize.w,
                    height: _dotSize.w,
                    decoration: BoxDecoration(
                      color: context.colors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 알림 화면에서 돌아오면 읽음 상태가 바뀌었을 수 있어 다시 받음
  Future<void> _openNotifications(BuildContext context, WidgetRef ref) async {
    await context.push(Routes.guardianNotifications);
    await ref.read(unreadSummaryProvider.notifier).refresh();
  }
}

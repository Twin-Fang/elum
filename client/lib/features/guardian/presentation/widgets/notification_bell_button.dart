import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/periodic_refresh.dart';
import '../../../notification/application/unread_summary_provider.dart';

/// 머리 줄 종 아이콘 (Figma `alarm` 1724:7739): 안 읽은 알림·공지가 있으면 민트 원, 탭하면 알림 화면
///
/// 폰 홈 머리 줄 · 태블릿 옆 메뉴 공통. 앱이 앞으로 돌아올 때마다 요약을 다시 받음 (주기 갱신은 길게)
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  /// 아이콘 24 · 누르는 영역 44
  static const _iconSize = 24.0;
  static const _tapSize = 44.0;

  /// 누르는 영역 안에서 종이 놓인 여백 (가운데 정렬). 머리 줄이 배지 간격을 맞출 때 뺌
  static const iconInset = (_tapSize - _iconSize) / 2;

  /// 앱이 켜져 있는 동안 도는 갱신 주기 (푸시 수신 갱신은 #828)
  static const _refreshInterval = Duration(minutes: 5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(unreadSummaryProvider).value;
    final hasUnread = summary != null &&
        (summary.hasUnreadNotification || summary.hasUnreadNotice);

    return PeriodicRefresh(
      interval: _refreshInterval,
      onRefresh: () => ref.read(unreadSummaryProvider.notifier).refresh(),
      child: AppPressable(
        onTap: () => _onBellPressed(context, ref),
        scaleDown: AppPressable.scaleIcon,
        semanticLabel: _semanticLabelOf(context, hasUnread: hasUnread),
        child: SizedBox(
          width: _tapSize.w,
          height: _tapSize.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                AppAssets.notificationBell,
                width: _iconSize.w,
                height: _iconSize.w,
                colorFilter: ColorFilter.mode(
                  context.colors.notificationBellIcon,
                  BlendMode.srcIn,
                ),
              ),
              if (hasUnread)
                Positioned(
                  left: (iconInset + _UnreadDot.leftFromIcon).w,
                  top: (iconInset + _UnreadDot.topFromIcon).w,
                  child: const _UnreadDot(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 안 읽음 여부 > 화면 낭독기 이름 ("알림" 또는 "알림, 안 읽은 알림 있음")
  String _semanticLabelOf(BuildContext context, {required bool hasUnread}) {
    final l10n = context.l10n;
    if (!hasUnread) return l10n.notificationBellLabel;
    return '${l10n.notificationBellLabel}, ${l10n.notificationBellUnreadLabel}';
  }

  /// 알림 화면 열기 > 돌아오면 요약 다시 받기 (읽음 상태가 바뀌었을 수 있음)
  Future<void> _onBellPressed(BuildContext context, WidgetRef ref) async {
    await context.push(Routes.guardianNotifications);
    await ref.read(unreadSummaryProvider.notifier).refresh();
  }
}

/// 종 오른쪽 위 안 읽음 원 (시안 `Ellipse 35`)
class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  /// 지름 12 (안쪽 테두리 2 포함), 종 기준 오른쪽 13 · 위 -2
  static const size = 12.0;
  static const borderWidth = 2.0;
  static const leftFromIcon = 13.0;
  static const topFromIcon = -2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        color: colors.notificationBellUnreadDot,
        shape: BoxShape.circle,
        // 종과 겹친 자리를 바탕색 테두리로 끊어 보임
        border: Border.all(
          color: colors.notificationBellUnreadDotBorder,
          width: borderWidth.w,
        ),
      ),
    );
  }
}

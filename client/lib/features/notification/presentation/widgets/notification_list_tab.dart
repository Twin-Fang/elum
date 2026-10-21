import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../member/application/member_providers.dart';
import '../../application/notification_day_grouping.dart';
import '../../application/notification_list_controller.dart';
import '../../application/notification_navigator.dart';
import '../../application/notification_target.dart';
import '../../domain/app_notification.dart';
import 'notification_copy.dart';
import 'notification_row.dart';
import 'notifications_empty_body.dart';

/// 알림 탭: 날짜별 묶음 목록, 끝에 닿으면 다음 쪽, 당겨서 새로고침
///
/// 상태 넷: 불러오는 중 / 0건 / 실패(다시 하기 + 에러 코드) / 목록
class NotificationListTab extends ConsumerStatefulWidget {
  const NotificationListTab({super.key});

  @override
  ConsumerState<NotificationListTab> createState() => _NotificationListTabState();
}

class _NotificationListTabState extends ConsumerState<NotificationListTab> {
  final _scrollController = ScrollController();

  /// 끝까지 이만큼 남으면 다음 쪽을 받는다
  static const _loadMoreExtent = 320.0;
  static const _sidePadding = 16.0;
  static const _rowGap = 8.0;
  /// 묶음 사이 24 = 마지막 줄 아래 _rowGap 8 + 16 (시안 1724:8346)
  static const _groupGap = 16.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (_scrollController.position.extentAfter < _loadMoreExtent) {
      ref.read(notificationListControllerProvider.notifier).loadMore();
    }
  }

  void _onRowTapped(AppNotification notification) {
    ref.read(notificationListControllerProvider.notifier).markRead(notification.id);
    ref
        .read(notificationNavigatorProvider)
        .open(context, NotificationTarget.fromNotification(notification));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationListControllerProvider);
    final controller = ref.read(notificationListControllerProvider.notifier);

    return switch (async) {
      AsyncData(value: final state) when state.items.isEmpty => RefreshIndicator(
          onRefresh: controller.refresh,
          child: const ElumStateBody(child: NotificationsEmptyBody()),
        ),
      AsyncData(value: final state) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: _list(state),
        ),
      AsyncError(:final error) => ElumStateBody(
          child: ElumErrorView.failure(
            error,
            fallback: context.l10n.notificationListFailed,
            fallbackCode: 'E-NOTIF-LIST',
            onRetry: controller.refresh,
          ),
        ),
      _ => const ElumStateBody.loading(),
    };
  }

  Widget _list(NotificationListState state) {
    final groups = groupByDay(state.items, DateTime.now());
    // 이룸이가 2명 이상일 때만 줄마다 이름을 보임
    final isProfileNameVisible =
        (ref.watch(memberProvider).value?.profiles.length ?? 0) >= 2;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        _sidePadding.w,
        context.space.md,
        _sidePadding.w,
        context.space.xl,
      ),
      children: [
        for (var index = 0; index < groups.length; index++) ...[
          if (index > 0) SizedBox(height: _groupGap.h),
          _DayHeader(
            label: notificationDayLabel(context.l10n, groups[index].$1),
            // 전체 읽음은 맨 위 머리글 줄에만 둔다
            hasMarkAllRead: index == 0 && state.hasUnread,
            onMarkAllRead: () => ref
                .read(notificationListControllerProvider.notifier)
                .markAllRead(),
          ),
          for (final notification in groups[index].$2) ...[
            NotificationRow(
              notification: notification,
              day: groups[index].$1,
              isProfileNameVisible: isProfileNameVisible,
              onTap: () => _onRowTapped(notification),
            ),
            SizedBox(height: _rowGap.h),
          ],
        ],
        if (state.isLoadingMore)
          Padding(
            padding: EdgeInsets.only(top: context.space.md),
            child: Center(
              child: ElumSpinner(
                size: 24.w,
                color: context.colors.creditHistoryMutedText,
              ),
            ),
          ),
      ],
    );
  }
}

/// 날짜 묶음 머리글, 맨 위 줄 오른쪽에 `모두 읽음`
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.hasMarkAllRead,
    required this.onMarkAllRead,
  });

  final String label;
  final bool hasMarkAllRead;
  final VoidCallback onMarkAllRead;

  /// 머리글 > 첫 줄 8 (시안 1724:8346)
  static const _bottomGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final mutedStyle = context.typo.creditHistoryDate.copyWith(
      color: context.colors.notificationMutedText,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: _bottomGap.h),
      child: Row(
        children: [
          Expanded(child: Text(label, style: mutedStyle)),
          if (hasMarkAllRead)
            AppPressable(
              onTap: onMarkAllRead,
              scaleDown: AppPressable.scaleIcon,
              child: Text(context.l10n.notificationMarkAllRead, style: mutedStyle),
            ),
        ],
      ),
    );
  }
}

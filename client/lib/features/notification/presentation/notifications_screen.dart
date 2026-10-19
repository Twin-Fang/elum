import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_segmented_tabs.dart';
import '../application/unread_summary_provider.dart';
import 'widgets/notice_history_tab.dart';
import 'widgets/notification_list_tab.dart';

/// 알림 화면: 위에 `알림 / 공지사항` 두 탭, 아래에 고른 탭의 목록 (종 아이콘으로 들어옴)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _notificationTabIndex = 0;
  static const _noticeTabIndex = 1;

  /// 뒤로가기 줄 아래 탭까지 간격
  static const _titleToTabsGap = 8.0;

  int _selectedTabIndex = _notificationTabIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = ref.watch(unreadSummaryProvider).value;

    return ElumScaffold(
      onBack: context.popOrHome,
      title: l10n.notificationTabNotifications,
      backTop: 67,
      // 탭 밑줄이 화면 폭 끝까지 가도록 여백은 안쪽 위젯이 각자 둔다
      horizontalPadding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _titleToTabsGap.h),
          ElumSegmentedTabs(
            tabs: [
              ElumTab(
                label: l10n.notificationTabNotifications,
                hasDot: summary?.hasUnreadNotification ?? false,
              ),
              ElumTab(
                label: l10n.notificationTabNotices,
                hasDot: summary?.hasUnreadNotice ?? false,
              ),
            ],
            selectedIndex: _selectedTabIndex,
            onSelected: (index) => setState(() => _selectedTabIndex = index),
          ),
          Expanded(
            child: _selectedTabIndex == _noticeTabIndex
                ? const NoticeHistoryTab()
                : const NotificationListTab(),
          ),
        ],
      ),
    );
  }
}

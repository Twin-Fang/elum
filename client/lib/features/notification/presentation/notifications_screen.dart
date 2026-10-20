import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_segmented_tabs.dart';
import '../application/unread_summary_provider.dart';
import 'widgets/notification_settings_gear_button.dart';
import 'widgets/notice_history_tab.dart';
import 'widgets/notification_list_tab.dart';

/// 알림 화면: 위에 `알림 / 공지사항` 두 탭, 아래에 고른 탭의 목록 (종 아이콘 · 내정보 `공지사항` 줄로 들어옴)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.isNoticeTabInitiallySelected = false});

  /// 공지사항 탭이 골라진 채로 연다 (내정보 `공지사항` 줄)
  final bool isNoticeTabInitiallySelected;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _notificationTabIndex = 0;
  static const _noticeTabIndex = 1;

  /// 뒤로가기 줄 아래 탭까지 간격
  static const _titleToTabsGap = 8.0;

  /// 제목 줄(뒤로가기 상자와 같은 높이) 오른쪽 끝 여백
  static const _gearRight = 16.0;
  static const _titleRowTop = 67.0;

  late int _selectedTabIndex = widget.isNoticeTabInitiallySelected
      ? _noticeTabIndex
      : _notificationTabIndex;

  /// 공지 탭을 한 번이라도 열었나 (처음 열 때 만들고, 이후 오가도 유지해 본 공지 기록을 한 번만 보냄)
  late bool _isNoticeTabOpened = widget.isNoticeTabInitiallySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = ref.watch(unreadSummaryProvider).value;

    // 톱니는 스캐폴드 제목 줄 위에 겹쳐 놓음 (제목 줄 y = 뒤로가기 backTop)
    final safeTop = MediaQuery.paddingOf(context).top;
    final gearTop = _titleRowTop.h < safeTop ? 0.0 : _titleRowTop.h - safeTop;

    final scaffold = ElumScaffold(
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
            onSelected: (index) => setState(() {
              _selectedTabIndex = index;
              if (index == _noticeTabIndex) _isNoticeTabOpened = true;
            }),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                const NotificationListTab(),
                if (_isNoticeTabOpened) const NoticeHistoryTab() else const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        scaffold,
        Positioned(
          top: safeTop + gearTop,
          right: _gearRight.w,
          child: const NotificationSettingsGearButton(),
        ),
      ],
    );
  }
}

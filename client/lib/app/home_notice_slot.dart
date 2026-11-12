import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/widgets/home_notice_card.dart';
import '../features/notification/application/device_notification_permission_controller.dart';
import 'home_auto_send_upsell.dart';
import 'home_auto_send_upsell_card.dart';
import 'home_notice_priority.dart';
import 'home_suggestion_card.dart';
import 'low_credit_notice_card.dart';
import 'notification_off_notice_card.dart';

/// 보호자 홈 안내 카드 자리 (한 번에 하나): 우선순위 [homeNoticeChoiceProvider] > 종류별 카드 > 나타남·접힘 전환
///
/// 보인 순간 기록 2개: 권유 카드 하루 1개 기록, 자동 보내기 안내 처음 보인 날.
/// 앱이 다시 앞으로 오면 기기 알림 권한을 다시 읽음 (켜졌으면 알림 꺼짐 카드가 바로 사라짐)
class HomeNoticeSlot extends ConsumerStatefulWidget {
  const HomeNoticeSlot({super.key, required this.onCreateRoutine, required this.bottomGap});

  /// 일과 만들기 시작 (권유 카드 `일과 더 만들기`)
  final Future<void> Function() onCreateRoutine;

  /// 카드 아래 간격 (카드가 보일 때만)
  final double bottomGap;

  @override
  ConsumerState<HomeNoticeSlot> createState() => _HomeNoticeSlotState();
}

class _HomeNoticeSlotState extends ConsumerState<HomeNoticeSlot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(deviceNotificationPermissionControllerProvider.notifier).recheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final choice = ref.watch(homeNoticeChoiceProvider);
    if (choice != null) _recordShownAfterFrame(choice);
    return HomeNoticeSwitcher(
      child: choice == null
          ? null
          : Padding(
              key: ValueKey(choice.kind),
              padding: EdgeInsets.only(bottom: widget.bottomGap.h),
              child: _cardOf(choice.kind),
            ),
    );
  }

  Widget _cardOf(HomeNoticeKind kind) => switch (kind) {
    HomeNoticeKind.notificationOff => const NotificationOffNoticeCard(),
    HomeNoticeKind.lowCredit => const LowCreditNoticeCard(),
    HomeNoticeKind.suggestion => HomeSuggestionCard(onCreateRoutine: widget.onCreateRoutine),
    HomeNoticeKind.autoSendUpsell => const HomeAutoSendUpsellCard(),
  };

  // 그리기가 끝난 뒤 기록 (build 중 상태 변경 금지). 이미 기록된 날이면 각 기록이 아무것도 안 함
  void _recordShownAfterFrame(HomeNoticeChoice choice) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (choice.isUpsell) unawaited(ref.read(homeUpsellShownRecordProvider.notifier).markShown(choice.kind, now));
      if (choice.kind == HomeNoticeKind.autoSendUpsell) {
        unawaited(ref.read(homeAutoSendUpsellRecordProvider.notifier).markShown(now));
      }
    });
  }
}

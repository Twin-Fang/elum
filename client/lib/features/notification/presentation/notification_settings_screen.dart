import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../application/device_notification_permission_controller.dart';
import '../application/notification_settings_controller.dart';
import 'widgets/device_notification_permission_banner.dart';
import 'widgets/notification_setting_rows.dart';

/// 알림 설정 화면: (기기 알림 꺼짐 띠 + 스위치 흐리게 잠금) + 모든 알림 받기 + 종류별 7개
/// 상태: 불러오는 중 / 실패(다시 하기 + 에러 코드) / 목록 (시안 1732:8563 켜짐, 1732:8433 기기 알림 꺼짐)
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  /// 제목 줄 y (시안 뒤로가기 67) · 제목 줄 아래 첫 카드까지 24 · 띠 아래 24
  static const _titleRowTop = 67.0;
  static const _topGap = 24.0;
  static const _bannerBottomGap = 24.0;

  /// 기기 알림 꺼짐 동안 스위치 묶음 투명도 (시안 1732:8433)
  static const _lockedOpacity = 0.4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notificationSettingsControllerProvider.notifier);
    final isPermissionOff = ref.watch(deviceNotificationPermissionControllerProvider);
    final body = switch (ref.watch(notificationSettingsControllerProvider)) {
      AsyncData(value: final settings) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: _topGap.h),
              // 띠는 꺼짐 동안만 보이지만, 설정 앱에서 돌아올 때 다시 확인하려고 항상 붙여 둔다
              const DeviceNotificationPermissionBanner(),
              if (isPermissionOff) SizedBox(height: _bannerBottomGap.h),
              // 기기 알림 꺼짐: 스위치가 효과 없으므로 전부 꺼진 모양으로 흐리게, 조작 막음 (저장값은 유지)
              Opacity(
                opacity: isPermissionOff ? _lockedOpacity : 1,
                child: IgnorePointer(
                  ignoring: isPermissionOff,
                  child: NotificationSettingRows(
                    settings: settings,
                    isShownAllOff: isPermissionOff,
                  ),
                ),
              ),
            ],
          ),
        ),
      AsyncError(:final error) => ElumStateBody(
          child: ElumErrorView.failure(
            error,
            fallback: context.l10n.notificationSettingLoadFailed,
            fallbackCode: 'E-NOTIF-SETTING-LOAD',
            onRetry: controller.reload,
          ),
        ),
      _ => const ElumStateBody.loading(),
    };

    return ElumScaffold(
      onBack: context.popOrHome,
      title: context.l10n.notificationSettingsTitle,
      backTop: _titleRowTop,
      child: body,
    );
  }
}

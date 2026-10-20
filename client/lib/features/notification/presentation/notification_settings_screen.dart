import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../application/device_notification_permission_controller.dart';
import '../application/notification_settings_controller.dart';
import 'widgets/device_notification_permission_banner.dart';
import 'widgets/notification_setting_rows.dart';

/// 알림 설정 화면: (기기 알림이 꺼졌으면 안내 띠 + 스위치 잠금) + 푸시 스위치 6개
/// 상태: 불러오는 중 / 실패(다시 하기 + 에러 코드) / 목록
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const _sectionGap = 16.0;
  static const _topGap = 8.0;
  static const _lockedHintGap = 8.0;
  static const _lockedHintPaddingH = 4.0;

  /// 기기 알림 꺼짐 동안 스위치 투명도
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
              const DeviceNotificationPermissionBanner(),
              SizedBox(height: _sectionGap.h),
              // 기기 알림 꺼짐: 스위치가 효과 없으므로 값만 흐리게 보이고 조작 막음
              Opacity(
                opacity: isPermissionOff ? _lockedOpacity : 1,
                child: IgnorePointer(
                  ignoring: isPermissionOff,
                  child: NotificationSettingRows(settings: settings),
                ),
              ),
              if (isPermissionOff)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _lockedHintPaddingH.w,
                    _lockedHintGap.h,
                    _lockedHintPaddingH.w,
                    0,
                  ),
                  child: Text(
                    context.l10n.notificationSettingsLockedHint,
                    style: context.typo.bodySmall
                        .copyWith(color: context.colors.textSecondary),
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
      child: body,
    );
  }
}

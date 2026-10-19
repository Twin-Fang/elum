import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_switch_tile.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../application/notification_settings_controller.dart';
import '../../domain/notification_settings.dart';

/// 알림 설정 스위치 묶음: 모든 알림 받기 + 종류별 5개 (all 이 꺼지면 종류별은 회색, 값 유지)
class NotificationSettingRows extends ConsumerWidget {
  const NotificationSettingRows({super.key, required this.settings});

  final NotificationSettings settings;

  static const _groupGap = 16.0;

  /// 비활성 스위치 투명도
  static const _disabledOpacity = 0.4;

  Future<void> _onToggled(
    BuildContext context,
    WidgetRef ref,
    NotificationSettingField field,
    bool value,
  ) async {
    final error = await ref
        .read(notificationSettingsControllerProvider.notifier)
        .toggle(field, value);
    if (error == null || !context.mounted) return;
    await showFailure(
      context,
      error,
      fallback: context.l10n.notificationSettingSaveFailed,
      fallbackCode: 'E-NOTIF-SETTING',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typeLabels = {
      NotificationSettingField.routineCompleted: l10n.notificationSettingRoutineCompleted,
      NotificationSettingField.routineSent: l10n.notificationSettingRoutineSent,
      NotificationSettingField.coGuardianJoined: l10n.notificationSettingCoGuardianJoined,
      NotificationSettingField.creditRefilled: l10n.notificationSettingCreditRefilled,
      NotificationSettingField.feedbackResolved: l10n.notificationSettingFeedbackResolved,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          hasDividers: false,
          children: [
            SettingsSwitchTile(
              isInCard: true,
              label: l10n.notificationSettingAll,
              value: settings.isAllEnabled,
              onChanged: (on) =>
                  _onToggled(context, ref, NotificationSettingField.all, on),
            ),
          ],
        ),
        SizedBox(height: _groupGap.h),
        SettingsGroup(
          hasDividers: false,
          children: [
            for (final entry in typeLabels.entries)
              Opacity(
                opacity: settings.isAllEnabled ? 1 : _disabledOpacity,
                child: IgnorePointer(
                  ignoring: !settings.isAllEnabled,
                  child: SettingsSwitchTile(
                    isInCard: true,
                    label: entry.value,
                    value: settings.valueOf(entry.key),
                    onChanged: (on) => _onToggled(context, ref, entry.key, on),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../application/device_notification_permission_controller.dart';

/// 기기 알림이 꺼져 있을 때만 보이는 얇은 안내 띠: 꺼짐 아이콘 + 한 줄 + 검정 알약 "켜기"
/// 설정 앱에서 돌아오면(resume) 권한을 다시 확인해 띠를 걷음
class DeviceNotificationPermissionBanner extends ConsumerStatefulWidget {
  const DeviceNotificationPermissionBanner({super.key});

  @override
  ConsumerState<DeviceNotificationPermissionBanner> createState() =>
      _DeviceNotificationPermissionBannerState();
}

class _DeviceNotificationPermissionBannerState
    extends ConsumerState<DeviceNotificationPermissionBanner>
    with WidgetsBindingObserver {
  static const _minHeight = 48.0;
  static const _paddingLeft = 14.0;
  static const _paddingRight = 8.0;
  static const _iconSize = 18.0;
  static const _iconToTextGap = 8.0;
  static const _radius = 14.0;

  /// 알약 버튼 (높이 32, 띠 여백 포함 터치 48)
  static const _pillHeight = 32.0;
  static const _pillPaddingH = 14.0;

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
    final isPermissionOff = ref.watch(deviceNotificationPermissionControllerProvider);
    if (!isPermissionOff) return const SizedBox.shrink();
    final colors = context.colors;
    final l10n = context.l10n;
    final controller = ref.read(deviceNotificationPermissionControllerProvider.notifier);

    return Container(
      constraints: BoxConstraints(minHeight: _minHeight.h),
      padding: EdgeInsets.only(left: _paddingLeft.w, right: _paddingRight.w),
      decoration: BoxDecoration(
        color: colors.buttonNeutral,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: _iconSize.r,
            color: colors.textSecondary,
          ),
          SizedBox(width: _iconToTextGap.w),
          Expanded(
            child: Text(
              l10n.notificationPermissionOff,
              style: context.typo.bodySmall.copyWith(color: colors.textPrimary),
            ),
          ),
          AppPressable(
            onTap: controller.turnOn,
            child: Container(
              height: _pillHeight.h,
              padding: EdgeInsets.symmetric(horizontal: _pillPaddingH.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.buttonEnabled,
                borderRadius: BorderRadius.circular(_pillHeight.h / 2),
              ),
              child: Text(
                l10n.notificationTurnOnDeviceNotification,
                style: context.typo.bodySmall.copyWith(
                  color: colors.buttonEnabledText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

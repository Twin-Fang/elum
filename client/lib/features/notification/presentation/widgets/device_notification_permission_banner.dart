import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../application/device_notification_permission_controller.dart';

/// 기기 알림이 꺼져 있을 때만 보이는 띠: 종+사선 아이콘 + 한 줄 + 검정 `켜기` (시안 1732:8433)
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
  /// 띠 56 높이(최소) · 모서리 20 · 왼쪽 20 · 오른쪽 12 (시안 1732:8433 실측 11 > 간격 단계)
  static const _minHeight = 56.0;
  static const _radius = 20.0;
  static const _paddingLeft = 20.0;
  static const _paddingRight = 12.0;

  /// 아이콘 22×20 · 아이콘 > 글 12 (실측 글 시작 x=70, 글자 앞 여백 포함)
  static const _iconWidth = 22.0;
  static const _iconHeight = 20.0;
  static const _iconToTextGap = 12.0;

  /// `켜기` 버튼 (높이 34, 좌우 20, 모서리 8)
  static const _buttonHeight = 34.0;
  static const _buttonPaddingH = 20.0;
  static const _buttonRadius = 8.0;
  static const _textToButtonGap = 8.0;

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
        color: colors.notificationPermissionBannerBg,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            AppAssets.iconNotificationOff,
            width: _iconWidth.w,
            height: _iconHeight.w,
            excludeFromSemantics: true,
          ),
          SizedBox(width: _iconToTextGap.w),
          Expanded(
            child: Text(
              l10n.notificationPermissionOff,
              style: context.typo.settingsTileLabel
                  .copyWith(color: colors.notificationMutedText),
            ),
          ),
          SizedBox(width: _textToButtonGap.w),
          AppPressable(
            onTap: controller.turnOn,
            child: Container(
              height: _buttonHeight.h,
              padding: EdgeInsets.symmetric(horizontal: _buttonPaddingH.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.buttonEnabled,
                borderRadius: BorderRadius.circular(_buttonRadius.r),
              ),
              child: Text(
                l10n.notificationTurnOnDeviceNotification,
                style: context.typo.notificationBannerButton
                    .copyWith(color: colors.buttonEnabledText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

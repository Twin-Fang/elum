import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 알림 화면 제목 줄 오른쪽의 톱니 버튼: 알림 설정으로 이동
class NotificationSettingsGearButton extends StatelessWidget {
  const NotificationSettingsGearButton({super.key});

  /// 누르는 영역 40 (뒤로가기 상자와 같음) · 그림 24
  static const tapSize = 40.0;
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () => context.push(Routes.guardianNotificationSettings),
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: context.l10n.notificationSettingsTitle,
      child: SizedBox(
        width: tapSize.w,
        height: tapSize.w,
        child: Center(
          child: SvgPicture.asset(
            AppAssets.iconSettings,
            width: _iconSize.w,
            height: _iconSize.w,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'min_tap_target.dart';

/// 보호자 홈의 알림 꺼짐 안내 카드 (가로 한 단): 루미 타일 + 제목과 한 문장 + `켜기` + 닫기 x
/// 글과 동작은 부르는 쪽이 넘김 (`lib/app/notification_off_notice_host.dart`)
class NotificationOffNotice extends StatelessWidget {
  const NotificationOffNotice({
    super.key,
    required this.title,
    required this.body,
    required this.turnOnLabel,
    required this.onTurnOn,
    required this.onDismiss,
    required this.dismissLabel,
  });

  final String title;
  final String body;
  final String turnOnLabel;
  final VoidCallback onTurnOn;
  final VoidCallback onDismiss;

  /// 닫기 x 낭독 글
  final String dismissLabel;

  static const _radius = 20.0;
  static const _shadowBlur = 14.0;
  static const _shadowOffsetY = 4.0;
  static const _closeIconSize = 12.0;

  /// 루미 타일 48 (모서리 16), 그림은 타일 아래로 살짝 잘림
  static const _tileSize = 48.0;
  static const _tileRadius = 16.0;
  static const _lumiWidth = 42.0;
  static const _lumiTop = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_radius.r),
        boxShadow: [
          BoxShadow(color: colors.homeCardShadow, blurRadius: _shadowBlur.r, offset: Offset(0, _shadowOffsetY.h)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(left: space.sm.w, top: space.sm.h, bottom: space.sm.h),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_tileRadius.r),
              child: Container(
                width: _tileSize.w,
                height: _tileSize.w,
                color: colors.proPlanTileExtra,
                alignment: Alignment.topCenter,
                padding: EdgeInsets.only(top: _lumiTop.w),
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: double.infinity,
                  child: Image.asset(AppAssets.notificationsEmptyLumi, width: _lumiWidth.w, excludeFromSemantics: true),
                ),
              ),
            ),
            SizedBox(width: space.sm.w),
            // 글은 줄이지 않고 줄을 바꿈 (큰 글자, 긴 번역에서도 잘리지 않게)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: context.typo.settingsGroupLabel.copyWith(color: colors.textPrimary)),
                  SizedBox(height: space.xs.h / 4),
                  Text(body, style: context.typo.creditCaption.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
            SizedBox(width: space.xs.w),
            NotificationTurnOnButton(label: turnOnLabel, onTap: onTurnOn),
            MinTapTarget(
              child: AppPressable(
                onTap: onDismiss,
                semanticLabel: dismissLabel,
                child: Padding(
                  padding: EdgeInsets.all(space.sm.w),
                  child: SvgPicture.asset(
                    AppAssets.iconClose,
                    width: _closeIconSize.w,
                    height: _closeIconSize.w,
                    excludeFromSemantics: true,
                    colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림 켜기 검정 버튼 (시안 1732:8433: 높이 34, 좌우 20, 모서리 8). 홈 카드와 알림 꺼짐 띠가 함께 씀
class NotificationTurnOnButton extends StatelessWidget {
  const NotificationTurnOnButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const _height = 34.0;
  static const _paddingH = 20.0;
  static const _radius = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: _height.h,
        padding: EdgeInsets.symmetric(horizontal: _paddingH.w),
        decoration: BoxDecoration(color: colors.buttonEnabled, borderRadius: BorderRadius.circular(_radius.r)),
        // 세로 목록 안에서도 글 폭만큼만 차지
        child: Center(
          widthFactor: 1,
          child: Text(label, style: context.typo.notificationBannerButton.copyWith(color: colors.buttonEnabledText)),
        ),
      ),
    );
  }
}

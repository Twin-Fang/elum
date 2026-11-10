import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'min_tap_target.dart';

/// 알림 꺼짐 안내 모양 두 가지: 한 줄(보호자 홈) · 카드(알림 화면 맨 위)
enum NotificationOffNoticeStyle { compact, card }

/// 알림 꺼짐 안내 단일 부품 (보호자 화면 전용: 홈 · 알림 화면). 글·동작은 부르는 쪽이 넘김 (`lib/app/notification_off_notice_host.dart`)
///
/// 한 줄: 종+사선 아이콘 + 제목 + 어두운 알약 `켜기` + (있으면) 닫기 x. 카드: 제목 + 본문 + 알약 + 루미 그림
class NotificationOffNotice extends StatelessWidget {
  const NotificationOffNotice({
    super.key,
    required this.style,
    required this.title,
    required this.turnOnLabel,
    required this.onTurnOn,
    this.body,
    this.onDismiss,
    this.dismissLabel,
  });

  final NotificationOffNoticeStyle style;
  final String title;

  /// 카드 본문 (한 줄 모양은 안 씀)
  final String? body;
  final String turnOnLabel;
  final VoidCallback onTurnOn;

  /// 닫기(x) 누름 (null 이면 닫기 없음)
  final VoidCallback? onDismiss;
  final String? dismissLabel;

  static const _cardRadius = 18.0;
  static const _iconSize = 16.0;
  static const _closeIconSize = 12.0;
  static const _lumiSize = 72.0;
  static const _shadowBlur = 12.0;

  @override
  Widget build(BuildContext context) => switch (style) {
    NotificationOffNoticeStyle.compact => _compact(context),
    NotificationOffNoticeStyle.card => _card(context),
  };

  Widget _compact(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final onDismiss = this.onDismiss;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(space.pillRadius.r),
        boxShadow: [BoxShadow(color: colors.homeCardShadow, blurRadius: _shadowBlur.r)],
      ),
      child: Padding(
        padding: EdgeInsets.only(left: space.md.w, right: space.xs.w, top: space.xs.h / 2, bottom: space.xs.h / 2),
        child: Row(
          children: [
            SvgPicture.asset(
              AppAssets.iconBellSlash,
              width: _iconSize.w,
              height: _iconSize.w,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            SizedBox(width: space.xs.w),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.typo.settingsGroupLabel.copyWith(color: colors.textPrimary)),
            ),
            NotificationTurnOnPill(label: turnOnLabel, onTap: onTurnOn),
            if (onDismiss != null)
              MinTapTarget(
                child: AppPressable(
                  onTap: onDismiss,
                  semanticLabel: dismissLabel,
                  child: Padding(
                    padding: EdgeInsets.all(space.xs.w),
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

  Widget _card(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final body = this.body;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.proPlanTileExtra, borderRadius: BorderRadius.circular(_cardRadius.r)),
      child: Padding(
        padding: EdgeInsets.all(space.md.w),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.typo.settingsGroupLabel.copyWith(color: colors.textPrimary)),
                  if (body != null) ...[
                    SizedBox(height: space.xs.h / 2),
                    Text(body, style: context.typo.creditBody.copyWith(color: colors.textSecondary)),
                  ],
                  SizedBox(height: space.sm.h),
                  NotificationTurnOnPill(label: turnOnLabel, onTap: onTurnOn),
                ],
              ),
            ),
            SizedBox(width: space.xs.w),
            Image.asset(AppAssets.notificationsEmptyLumi, width: _lumiSize.w, excludeFromSemantics: true),
          ],
        ),
      ),
    );
  }
}

/// 어두운 알약 `켜기` 버튼 (홈 · 알림 화면 · 설정 줄이 함께 씀)
class NotificationTurnOnPill extends StatelessWidget {
  const NotificationTurnOnPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const _padH = 14.0;
  static const _padV = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MinTapTarget(
      child: AppPressable(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.buttonEnabled, borderRadius: BorderRadius.circular(context.space.pillRadius.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
            child: Text(label, style: context.typo.notificationBannerButton.copyWith(color: colors.buttonEnabledText)),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../application/notification_day_grouping.dart';
import '../../domain/app_notification.dart';
import '../../domain/notification_type.dart';
import 'notification_copy.dart';

/// 알림 한 줄 (시안 1724:8346): 민트 네모 아이콘 > (이룸이 이름) 문장 > 시각 > 안 읽음 점
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.day,
    required this.isProfileNameVisible,
    required this.onTap,
  });

  final AppNotification notification;
  final NotificationDay day;

  /// 이룸이가 2명 이상인 보호자에게만 문장 위에 이름을 보임
  final bool isProfileNameVisible;
  final VoidCallback onTap;

  /// 줄 56 높이(최소) · 좌우 10 · 위아래 10
  static const _minHeight = 56.0;
  static const _paddingH = 10.0;
  static const _paddingV = 10.0;

  /// 아이콘 상자 36 (모서리 12) · 그림 16
  static const _iconBoxSize = 36.0;
  static const _iconBoxRadius = 12.0;
  static const _iconSize = 16.0;

  /// 아이콘 > 문장 8 · 문장 > 시각 8 · 시각 > 점 6 · 점 8
  static const _iconToTextGap = 8.0;
  static const _textToTimeGap = 8.0;
  static const _timeToDotGap = 6.0;
  static const _unreadDotSize = 8.0;
  static const _nameToHeadlineGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final profileName = notification.profileName;
    final headline = notificationHeadline(context.l10n, notification);
    final timeLabel = notificationTimeLabel(context, day, notification.occurredAt);
    final mutedStyle = typo.notificationRowTime.copyWith(color: colors.notificationMutedText);

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        constraints: BoxConstraints(minHeight: _minHeight.h),
        padding: EdgeInsets.symmetric(horizontal: _paddingH.w, vertical: _paddingV.h),
        decoration: BoxDecoration(
          color: colors.creditCardBg,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        ),
        child: Row(
          children: [
            _NotificationTypeIcon(
              type: notification.type,
              boxSize: _iconBoxSize,
              boxRadius: _iconBoxRadius,
              iconSize: _iconSize,
            ),
            SizedBox(width: _iconToTextGap.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isProfileNameVisible && profileName != null) ...[
                    Text(
                      profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mutedStyle,
                    ),
                    SizedBox(height: _nameToHeadlineGap.h),
                  ],
                  Text(
                    headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typo.notificationRowText.copyWith(color: colors.notificationRowText),
                  ),
                ],
              ),
            ),
            SizedBox(width: _textToTimeGap.w),
            Text(timeLabel, style: mutedStyle),
            SizedBox(width: _timeToDotGap.w),
            // 읽은 줄도 자리를 비워 시각 끝선을 맞춘다
            Container(
              width: _unreadDotSize.w,
              height: _unreadDotSize.w,
              decoration: BoxDecoration(
                color: notification.isRead ? Colors.transparent : colors.notificationUnreadDot,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 종류 > 민트 네모 안 흰 아이콘
/// 시안 있는 3종(완료·보냄·합류)은 Figma 에셋, 나머지 4종은 시안이 없어 같은 상자에 Material 아이콘
class _NotificationTypeIcon extends StatelessWidget {
  const _NotificationTypeIcon({
    required this.type,
    required this.boxSize,
    required this.boxRadius,
    required this.iconSize,
  });

  final NotificationType type;
  final double boxSize;
  final double boxRadius;
  final double iconSize;

  /// 종류 > fi-br 아이콘 (시안 1724:8346: 체크 · 종이비행기 · 사람 더하기, 나머지는 같은 벌)
  static String _assetOf(NotificationType type) => switch (type) {
        NotificationType.routineCompleted => AppAssets.iconNotificationCheck,
        NotificationType.routineSentByCoGuardian => AppAssets.iconNotificationPaperPlane,
        NotificationType.coGuardianJoined => AppAssets.iconNotificationUserAdd,
        NotificationType.creditRefilled => AppAssets.iconCoins,
        NotificationType.feedbackResolved => AppAssets.iconComment,
        NotificationType.talkPostCommented => AppAssets.iconComments,
        NotificationType.talkPostImported => AppAssets.iconDownload,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: boxSize.w,
      height: boxSize.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.notificationIconBackground,
        borderRadius: BorderRadius.circular(boxRadius.r),
      ),
      // 아이콘 색은 종류마다 바꾸지 않음 (흰 16, §3-5)
      child: SvgPicture.asset(
        _assetOf(type),
        width: iconSize.w,
        height: iconSize.w,
        colorFilter: ColorFilter.mode(
          colors.notificationIconForeground,
          BlendMode.srcIn,
        ),
        excludeFromSemantics: true,
      ),
    );
  }
}

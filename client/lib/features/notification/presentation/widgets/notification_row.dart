import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../application/notification_day_grouping.dart';
import '../../domain/app_notification.dart';
import '../../domain/notification_type.dart';
import 'notification_copy.dart';

/// 알림 한 줄 (시안 1724:8346): 민트 네모 아이콘 > (이룸이 이름) 제목 · 오른쪽 위 시각 · 안 읽음 점 > 회색 설명 한 줄
/// 모든 종류가 같은 틀 (설명이 없는 종류는 제목만, 한 줄이면 아이콘 높이 가운데)
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

  /// 좌우 10 · 위아래 10 (아이콘 36 과 합쳐 줄 최소 높이 56)
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
  static const _lineGap = 4.0;

  /// 제목 최대 2줄 · 설명 1줄
  static const _headlineMaxLines = 2;
  static const _detailMaxLines = 1;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final profileName = notification.profileName;
    final headline = notificationHeadline(context.l10n, notification);
    final detail = notificationDetailLine(context.l10n, notification);
    final headlineStyle = typo.notificationRowText.copyWith(color: colors.notificationRowText);
    final mutedStyle = typo.notificationRowTime.copyWith(color: colors.notificationMutedText);

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _paddingH.w, vertical: _paddingV.h),
        decoration: BoxDecoration(
          color: colors.creditCardBg,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationTypeIcon(
              type: notification.type,
              boxSize: _iconBoxSize,
              boxRadius: _iconBoxRadius,
              iconSize: _iconSize,
            ),
            SizedBox(width: _iconToTextGap.w),
            Expanded(
              // 글이 한 줄뿐이면 아이콘 높이 가운데, 길어지면 위에서부터
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: _iconBoxSize.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isProfileNameVisible && profileName != null) ...[
                      Text(profileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: mutedStyle),
                      SizedBox(height: _lineGap.h),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            // 어절 단위 줄바꿈 (한 글자만 다음 줄로 넘어가지 않게), 낭독기는 원문
                            keepWords(headline, locale: context.appLocale),
                            semanticsLabel: headline,
                            maxLines: _headlineMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: headlineStyle,
                          ),
                        ),
                        SizedBox(width: _textToTimeGap.w),
                        _TimeAndUnreadDot(
                          timeLabel: notificationTimeLabel(context, day, notification.occurredAt),
                          isRead: notification.isRead,
                          firstLineStyle: headlineStyle,
                          timeStyle: mutedStyle,
                          gap: _timeToDotGap,
                          dotSize: _unreadDotSize,
                        ),
                      ],
                    ),
                    if (detail != null) ...[
                      SizedBox(height: _lineGap.h),
                      Text(detail, maxLines: _detailMaxLines, overflow: TextOverflow.ellipsis, style: mutedStyle),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시각 > 안 읽음 점, 제목 첫 줄 높이 가운데에 맞춤 (글자 배율이 달라도 첫 줄을 따라감)
class _TimeAndUnreadDot extends StatelessWidget {
  const _TimeAndUnreadDot({
    required this.timeLabel,
    required this.isRead,
    required this.firstLineStyle,
    required this.timeStyle,
    required this.gap,
    required this.dotSize,
  });

  final String timeLabel;
  final bool isRead;

  /// 제목 글자 모양 (첫 줄 높이를 재는 데만 씀)
  final TextStyle firstLineStyle;
  final TextStyle timeStyle;
  final double gap;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final firstLineHeight = MediaQuery.textScalerOf(context).scale(
      (firstLineStyle.fontSize ?? 0) * (firstLineStyle.height ?? 1),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: firstLineHeight),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(timeLabel, style: timeStyle),
          SizedBox(width: gap.w),
          // 읽은 줄도 자리를 비워 시각 끝선을 맞춘다
          Container(
            width: dotSize.w,
            height: dotSize.w,
            decoration: BoxDecoration(
              color: isRead ? Colors.transparent : context.colors.notificationUnreadDot,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 종류 > 민트 네모 안 흰 아이콘
/// 시안 있는 3종(완료·보냄·합류)은 Figma 에셋, 나머지 5종은 시안이 없어 같은 상자에 Material 아이콘
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
        NotificationType.weeklyReportReady => AppAssets.iconCalendar,
        NotificationType.adminMessage => AppAssets.iconBell,
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

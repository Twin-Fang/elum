import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../application/notification_day_grouping.dart';
import '../../domain/app_notification.dart';
import 'notification_copy.dart';

/// 알림 한 줄: 종류 아이콘, (이룸이 이름), 문장, 시각. 안 읽은 줄은 민트 바탕
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

  static const _padH = 16.0;
  static const _padV = 14.0;
  static const _iconCircleSize = 40.0;
  static const _iconSize = 22.0;
  static const _iconToTextGap = 12.0;
  static const _textToTimeGap = 8.0;
  static const _nameToHeadlineGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final profileName = notification.profileName;
    final headline = notificationHeadline(context.l10n, notification);
    final timeLabel = notificationTimeLabel(context, day, notification.occurredAt);

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: notification.isRead
              ? colors.creditCardBg
              : colors.notificationUnreadBackground,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
          child: Row(
            children: [
              Container(
                width: _iconCircleSize.w,
                height: _iconCircleSize.w,
                decoration: BoxDecoration(
                  color: colors.notificationIconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notificationIcon(notification.type),
                  size: _iconSize.w,
                  color: colors.textPrimary,
                ),
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
                        style: typo.creditHistoryRowDetail.copyWith(
                          color: colors.creditHistoryMutedText,
                        ),
                      ),
                      SizedBox(height: _nameToHeadlineGap.h),
                    ],
                    Text(
                      headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typo.creditHistoryRowTitle.copyWith(
                        color: colors.textPrimary,
                        // 기본 높이 1.0은 두 줄에서 글자가 붙는다
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: _textToTimeGap.w),
              Text(
                timeLabel,
                style: typo.creditHistoryRowDetail.copyWith(
                  color: colors.creditHistoryMutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

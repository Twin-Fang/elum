import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/layout_context_ext.dart';
import '../../../../core/layout/window_size_class.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_guide_panel.dart';
import '../../domain/app_notification.dart';

/// 의견 처리 알림을 누르면: 그림 > 제목 > 고마움 한 줄 > 내가 보낸 의견 칸 > 확인
/// 폰은 아래 시트, 태블릿은 가운데 창. 의견이 지워졌으면 의견 칸 없이 보임
Future<void> showFeedbackResolvedSheet(BuildContext context, AppNotification notification) {
  final isPhone = context.sizeClass == WindowSizeClass.compact;
  final placement = isPhone ? ElumGuidePlacement.sheet : ElumGuidePlacement.dialog;
  Widget panelOf(BuildContext sheetContext) =>
      _FeedbackResolvedPanel(placement: placement, notification: notification);
  return isPhone
      ? showElumGuideSheet<void>(context: context, builder: panelOf)
      : showElumGuideDialog<void>(context: context, builder: panelOf, barrierDismissible: true);
}

class _FeedbackResolvedPanel extends StatelessWidget {
  const _FeedbackResolvedPanel({required this.placement, required this.notification});

  final ElumGuidePlacement placement;
  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = notification.body?.trim();
    final hasMessage = message != null && message.isNotEmpty;
    return ElumGuidePanel(
      placement: placement,
      illustration: ElumGuideIllustration(
        asset: AppAssets.featureIconFeedbackResolved,
        size: placement == ElumGuidePlacement.sheet
            ? ElumGuideIllustrationSize.sheet
            : ElumGuideIllustrationSize.dialog,
      ),
      title: l10n.notificationFeedbackResolved,
      description: l10n.notificationFeedbackSheetBody,
      content: [
        if (hasMessage) _SentFeedbackQuote(message: message, sentAt: notification.feedbackSentAt),
      ],
      primaryAction: ElumGuideAction(label: l10n.commonConfirm, onTap: () => Navigator.of(context).pop()),
    );
  }
}

/// 보낸 의견 칸: 보낸 날짜 머리글(모르면 없음) > 의견 전문 (길면 칸 안에서 스크롤)
class _SentFeedbackQuote extends StatelessWidget {
  const _SentFeedbackQuote({required this.message, required this.sentAt});

  final String message;
  final DateTime? sentAt;

  /// 칸 모서리 16 · 머리글 > 본문 6 · 본문 최대 높이 (넘으면 스크롤)
  static const _radius = 16.0;
  static const _labelToBodyGap = 6.0;
  static const _bodyMaxHeight = 160.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final sentLocal = sentAt?.toLocal();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(space.md),
      decoration: BoxDecoration(
        color: colors.notificationFeedbackQuoteBg,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sentLocal != null) ...[
            Text(
              context.l10n.notificationFeedbackSentOn(sentLocal.month, sentLocal.day),
              style: typo.notificationRowTime.copyWith(color: colors.notificationMutedText),
            ),
            SizedBox(height: _labelToBodyGap.h),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _bodyMaxHeight.h),
            child: SingleChildScrollView(
              child: Text(message, style: typo.notificationRowText.copyWith(color: colors.notificationRowText)),
            ),
          ),
        ],
      ),
    );
  }
}

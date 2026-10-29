import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 이야기 빈 상태 · 안내 (보호자 화면 빈 상태 결): 그림 없이 제목 > 설명 > (있으면) 알약 버튼
/// 피드 0건 · 내려간 글 · 댓글 0건 · 숨긴 보호자 0명 · 올릴 일과 없음이 함께 쓴다
class TalkEmptyMessage extends StatelessWidget {
  const TalkEmptyMessage({
    super.key,
    required this.title,
    this.body,
    this.actionLabel,
    this.onActionPressed,
    this.isInPanel = false,
  });

  final String title;
  final String? body;

  /// 둘 다 있어야 버튼이 보인다
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  /// true 면 웜그레이 판에 담는다 (목록 사이에 끼는 자리: 댓글 0건)
  final bool isInPanel;

  /// 제목 > 설명 · 글 > 버튼 · 판 안쪽 여백
  static const _titleToBody = 8.0;
  static const _textToAction = 20.0;
  static const _panelPadding = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final body = this.body;
    final actionLabel = this.actionLabel;
    final onActionPressed = this.onActionPressed;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: typo.talkEmptyTitle.copyWith(color: colors.textPrimary),
        ),
        if (body != null) ...[
          SizedBox(height: _titleToBody.h),
          Text(
            // 어절 중간에서 꺾이지 않게
            keepWords(body, locale: context.appLocale),
            semanticsLabel: body,
            textAlign: TextAlign.center,
            style: typo.talkEmptyBody.copyWith(color: colors.talkMetaText),
          ),
        ],
        if (actionLabel != null && onActionPressed != null) ...[
          SizedBox(height: _textToAction.h),
          TalkPillButton(label: actionLabel, onPressed: onActionPressed),
        ],
      ],
    );

    return AppFadeSlideIn(
      offset: 8,
      child: isInPanel
          ? Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: _panelPadding.w,
                vertical: _panelPadding.h,
              ),
              decoration: BoxDecoration(
                color: colors.talkPanelFill,
                borderRadius: BorderRadius.circular(context.space.cardRadius.r),
              ),
              child: content,
            )
          : content,
    );
  }
}

/// 작은 알약 버튼 (남색 판 · 흰 글자 600/14, 높이 40): 빈 상태의 다음 걸음
class TalkPillButton extends StatelessWidget {
  const TalkPillButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  static const _height = 40.0;
  static const _paddingH = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 글자 폭만큼만 (부모가 폭을 꽉 주어도 늘어나지 않게)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          child: AppPressable(
            onTap: onPressed,
            child: Container(
              height: _height.h,
              padding: EdgeInsets.symmetric(horizontal: _paddingH.w),
              decoration: BoxDecoration(
                color: colors.textPrimary,
                borderRadius: BorderRadius.circular((_height / 2).r),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  style: context.typo.talkFormLabel.copyWith(
                    color: colors.surface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

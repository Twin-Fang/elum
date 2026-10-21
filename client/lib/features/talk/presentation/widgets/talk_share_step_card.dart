import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../domain/talk_preview.dart';
import 'talk_share_card_picture.dart';

/// 올리기 카드 한 장: 그림 > 순서 · 제목 > 설명 > (있으면) 아래 덧붙임 줄
/// 사진 고르기는 덧붙임 줄에 흐리게/그대로 선택을 넣는다
class TalkShareStepCard extends StatelessWidget {
  const TalkShareStepCard({
    super.key,
    required this.routineId,
    required this.step,
    required this.card,
    this.isBlurred = false,
    this.footer,
  });

  final String routineId;
  final TalkPreviewStep step;

  /// 일과관리 목록에서 못 찾았으면 null
  final ActionCard? card;
  final bool isBlurred;
  final Widget? footer;

  /// 그림 가로세로 비율
  static const _imageAspectRatio = 4 / 3;
  static const _numberSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final title = step.title ?? '';
    final footer = this.footer;

    return Container(
      padding: EdgeInsets.all(space.sm.w),
      decoration: BoxDecoration(
        color: colors.creditCardBg,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(space.sm.r),
            child: AspectRatio(
              aspectRatio: _imageAspectRatio,
              child: TalkShareCardPicture(
                routineId: routineId,
                card: card,
                label: title,
                isBlurred: isBlurred,
              ),
            ),
          ),
          SizedBox(height: space.sm.h),
          Row(
            children: [
              Container(
                width: _numberSize.w,
                height: _numberSize.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.textPrimary,
                ),
                child: Text(
                  '${step.cardNumber}',
                  style: typo.caption.copyWith(
                    color: colors.surface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: space.xs.w),
              Expanded(
                child: Text(
                  title,
                  style: typo.tileLabel.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          if (step.description.isNotEmpty) ...[
            SizedBox(height: space.xs.h),
            Text(
              step.description,
              style: typo.body.paragraph.copyWith(color: colors.textSecondary),
            ),
          ],
          if (footer != null) ...[SizedBox(height: space.sm.h), footer],
        ],
      ),
    );
  }
}

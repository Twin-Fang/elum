import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/example_card_image/bundled_card_art.dart';
import '../../domain/expert_routine.dart';

/// 미리 보기 카드 한 줄: 번호 > 그림 64 r12 > 문장 (흰 판 r20, 일과 언어 글꼴)
class ExpertRoutineStepRow extends StatelessWidget {
  const ExpertRoutineStepRow({
    super.key,
    required this.step,
    required this.number,
    required this.language,
  });

  final ExpertRoutineStep step;

  /// 1부터
  final int number;

  /// 카드 글 언어 코드
  final String language;

  static const _padding = 12.0;
  static const _artSize = 64.0;
  static const _artRadius = 12.0;
  static const _numberWidth = 24.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Container(
      padding: EdgeInsets.all(_padding.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        border: Border.all(color: colors.talkCardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _numberWidth.w,
            child: Text(
              '$number',
              textAlign: TextAlign.center,
              style: typo.talkPostTitle.copyWith(color: colors.talkMetaText),
            ),
          ),
          SizedBox(width: _gap.w),
          ClipRRect(
            borderRadius: BorderRadius.circular(_artRadius.r),
            child: SizedBox(
              width: _artSize.w,
              height: _artSize.w,
              child: BundledCardArt(
                label: step.text,
                pictogramId: step.pictogramId,
                exampleImageId: step.exampleImageId,
              ),
            ),
          ),
          SizedBox(width: _gap.w),
          Expanded(
            child: ContentLocale(
              language: language,
              child: Text(
                step.text,
                style: typo.talkPostTitle.copyWith(color: colors.talkTitleText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

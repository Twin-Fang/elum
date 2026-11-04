import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/example_card_image/bundled_card_art.dart';
import '../../domain/expert_routine.dart';

/// 목록 한 줄 (이야기 새 묶음 고르기 줄 결: 흰 판 r20 · 그림 52 r12 + 제목 600/16 + 메타)
/// 누르면 미리 보기
class ExpertRoutineTile extends StatelessWidget {
  const ExpertRoutineTile({super.key, required this.routine, required this.onTap});

  final ExpertRoutineSummary routine;
  final VoidCallback onTap;

  static const _padding = 16.0;
  static const _coverSize = 52.0;
  static const _coverRadius = 12.0;
  static const _coverToText = 12.0;
  static const _titleToMeta = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final summary = routine.summary;
    final category = routine.category;
    final meta = [
      ?category?.labelOf(l10n),
      l10n.expertRoutineStepCount(routine.stepCount),
    ].join(' · ');

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      semanticLabel: routine.title,
      child: Container(
        padding: EdgeInsets.all(_padding.w),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          border: Border.all(color: colors.talkCardBorder),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_coverRadius.r),
              child: SizedBox(
                width: _coverSize.w,
                height: _coverSize.w,
                child: BundledCardArt(
                  label: routine.title,
                  pictogramId: routine.coverPictogramId,
                  exampleImageId: routine.coverExampleImageId,
                ),
              ),
            ),
            SizedBox(width: _coverToText.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typo.talkPostTitle.copyWith(color: colors.talkTitleText),
                  ),
                  SizedBox(height: _titleToMeta.h),
                  Text(
                    summary ?? meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typo.talkPostNote.copyWith(color: colors.talkMetaText),
                  ),
                  if (summary != null) ...[
                    SizedBox(height: _titleToMeta.h),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.talkMeta.copyWith(color: colors.talkMetaText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

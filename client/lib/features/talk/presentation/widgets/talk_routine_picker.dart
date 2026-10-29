import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_empty_illustration.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../../core/widgets/routine_preview_hook.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../../shared/models/routine.dart';
import '../../../guardian/application/routine_providers.dart';
import '../../application/talk_shareable_routines_provider.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_empty_message.dart';
import 'talk_page_heading.dart';

/// 일과 고르기: 올릴 수 있는 일과를 일과관리 줄 모양(웜그레이 68 · 그림 · 제목 · 카드 수 · 꺾쇠)으로, 누르면 그 일과로 다음 단계
/// 상태: 받는 중 / 실패(다시 하기 + 에러 코드) / 없음 / 목록
class TalkRoutinePicker extends ConsumerWidget {
  const TalkRoutinePicker({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  /// 목록 좌우 · 머리 > 첫 줄 · 줄 사이 · 차례로 떠오르는 줄 수 상한
  static const _listInsetH = 16.0;
  static const _headingToList = 16.0;
  static const _rowGap = 8.0;
  static const _maxStaggerCount = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final routines = ref.watch(talkShareableRoutinesProvider);

    return switch (routines) {
      AsyncData(value: final routines) when routines.isEmpty => ElumStateBody(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.space.screenH.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ElumEmptyIllustration(),
              SizedBox(height: context.space.lg),
              TalkEmptyMessage(
                title: l10n.talkSharePickEmpty,
                body: l10n.talkSharePickEmptyHint,
              ),
            ],
          ),
        ),
      ),
      AsyncData(value: final routines) => ListView(
        padding: EdgeInsets.fromLTRB(
          _listInsetH.w,
          TalkPageHeading.topSpacing.h,
          _listInsetH.w,
          context.space.lg.h,
        ),
        children: [
          TalkPageHeading(title: l10n.talkSharePickTitle),
          SizedBox(height: _headingToList.h),
          for (var index = 0; index < routines.length; index++) ...[
            if (index > 0) SizedBox(height: _rowGap.h),
            AppFadeSlideIn(
              key: ValueKey(routines[index].id),
              offset: 8,
              delay: Duration(
                milliseconds:
                    AppMotion.staggerDelayMs *
                    (index < _maxStaggerCount ? index + 1 : _maxStaggerCount),
              ),
              child: _ShareableRoutineRow(
                routine: routines[index],
                onTap: () => onSelected(routines[index].id),
              ),
            ),
          ],
        ],
      ),
      AsyncError(:final error) => ElumStateBody(
        child: ElumErrorView.failure(
          error,
          fallback: l10n.talkSharePickFailed,
          fallbackCode: TalkScreenCodes.share,
          onRetry: () => ref
            ..invalidate(routineLibraryProvider)
            ..invalidate(talkShareableRoutinesProvider),
        ),
      ),
      _ => const ElumStateBody.loading(),
    };
  }
}

/// 올릴 일과 한 줄 (일과관리 줄 결, 시안 1870:9375): 그림 52 | 제목 > 카드 수 | 꺾쇠
class _ShareableRoutineRow extends ConsumerWidget {
  const _ShareableRoutineRow({required this.routine, required this.onTap});

  final Routine routine;
  final VoidCallback onTap;

  /// 일과관리 줄과 같은 높이 68 · 그림 쪽 8 · 오른쪽 16 · 위아래 8 · 제목 > 카드 수 8 (시안 x 24 · 84, 꺾쇠 x 337)
  static const _minHeight = 68.0;
  static const _padLeft = 8.0;
  static const _padRight = 16.0;
  static const _padV = 8.0;
  static const _titleToMeta = 8.0;
  static const _textToChevron = 8.0;

  /// 첫 카드 그림 한 변 · 둥글기 · 그림 > 글 (시안 52 · 12 · 8)
  static const _thumbnailSize = 52.0;
  static const _thumbnailRadius = 12.0;
  static const _thumbnailToText = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typo = context.typo;
    final buildThumbnail = ref.watch(routineThumbnailBuilderProvider);
    return Semantics(
      button: true,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleCard,
        child: Container(
          constraints: BoxConstraints(minHeight: _minHeight.h),
          padding: EdgeInsets.fromLTRB(
            _padLeft.w,
            _padV.h,
            _padRight.w,
            _padV.h,
          ),
          decoration: BoxDecoration(
            color: colors.routineTileBg,
            borderRadius: BorderRadius.circular(context.space.cardRadius.r),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_thumbnailRadius.w),
                child: SizedBox.square(
                  dimension: _thumbnailSize.w,
                  child: buildThumbnail(routine),
                ),
              ),
              SizedBox(width: _thumbnailToText.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      routine.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typo.routineTileTitle.copyWith(
                        color: colors.chipLabel,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: _titleToMeta.h),
                    Text(
                      context.l10n.talkDetailStepCount(routine.steps.length),
                      style: typo.routineTileMeta.copyWith(
                        color: colors.talkMetaText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: _textToChevron.w),
              const SettingsCardChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

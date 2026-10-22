import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../../shared/models/routine.dart';
import '../../../guardian/application/routine_providers.dart';
import '../../application/talk_shareable_routines_provider.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_empty_message.dart';
import 'talk_page_heading.dart';

/// 일과 고르기: 올릴 수 있는 일과를 일과관리 줄 모양(웜그레이 68 · 제목 · 카드 수 · 꺾쇠)으로, 누르면 그 일과로 다음 단계
/// 상태: 받는 중 / 실패(다시 하기 + 에러 코드) / 없음 / 목록
class TalkRoutinePicker extends ConsumerWidget {
  const TalkRoutinePicker({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  /// 목록 좌우 · 위 · 머리 > 첫 줄 · 줄 사이 · 차례로 떠오르는 줄 수 상한
  static const _listInsetH = 16.0;
  static const _listTop = 8.0;
  static const _headingToList = 24.0;
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
          child: TalkEmptyMessage(
            title: l10n.talkSharePickEmpty,
            body: l10n.talkSharePickEmptyHint,
          ),
        ),
      ),
      AsyncData(value: final routines) => ListView(
        padding: EdgeInsets.fromLTRB(
          _listInsetH.w,
          _listTop.h,
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

/// 올릴 일과 한 줄 (일과관리 줄 결): 제목 > 카드 수 | 꺾쇠
class _ShareableRoutineRow extends StatelessWidget {
  const _ShareableRoutineRow({required this.routine, required this.onTap});

  final Routine routine;
  final VoidCallback onTap;

  /// 일과관리 줄과 같은 높이 68 · 왼쪽 18 · 오른쪽 14 · 제목 > 카드 수 8
  static const _minHeight = 68.0;
  static const _padLeft = 18.0;
  static const _padRight = 14.0;
  static const _padV = 14.0;
  static const _titleToMeta = 8.0;
  static const _textToChevron = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
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

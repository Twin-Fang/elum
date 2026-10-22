import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../../shared/models/routine.dart';
import 'arrange_remove_badge.dart';
import 'library_routine_tile.dart';

/// 묶음 열기의 일과 한 줄 (행동카드 순서 변경과 같은 모양·동작): 카드 · 그림 · 제목 · `카드 N장`
///
/// 평소 오른쪽은 `›`, 순서 편집 중에는 ⊖ 와 손잡이. 번호는 이 줄에 없다 — 몇 번째 자리인가를 뜻해
/// 목록 왼쪽에 따로 서 있고(`RoutineDetailStepBadge`) 끌기에 끼지 않는다.
///
/// 손잡이는 **길게 눌러야 잡힌다** (스크롤하려던 손가락이 스치기만 해도 순서가 바뀌지 않게).
/// 누르는 동안 줄이 떠오르고, 다 떠오른 순간이 곧 잡힌 순간이라 진동으로 알린다.
class RoutineGroupSheetRow extends StatefulWidget {
  const RoutineGroupSheetRow({
    super.key,
    required this.index,
    required this.routine,
    required this.isEnabled,
    required this.isEditing,
    required this.isDragging,
    required this.onTap,
    required this.onRemove,
  });

  /// 묶음 안 순서 (0부터)
  final int index;
  final Routine routine;

  /// 저장 중이면 누르기·빼기·끌기를 막는다
  final bool isEnabled;

  /// 순서 편집 중인가 — 이때만 ⊖ 와 끌기 손잡이가 보인다 (시안)
  final bool isEditing;

  /// 지금 끌려가는 중인가. 끌기가 시작되면 이 줄은 시트 위의 사본으로 다시 그려지므로
  /// 들린 상태로 시작해야 그림자가 깜빡이지 않는다
  final bool isDragging;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// 줄 높이 — 왼쪽 번호 칸(`RoutineDetailStepBadge`)과 같아야 한다
  static const cardHeight = 68.0;

  @override
  State<RoutineGroupSheetRow> createState() => _RoutineGroupSheetRowState();
}

class _RoutineGroupSheetRowState extends State<RoutineGroupSheetRow>
    with SingleTickerProviderStateMixin {
  /// 누르고 있는 정도(0~1). 길이를 [kLongPressTimeout]에 맞춰야 실제로 잡히는 시점과 어긋나지 않는다
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: kLongPressTimeout,
    reverseDuration: AppMotion.fast,
    value: widget.isDragging ? 1 : 0,
  )..addStatusListener(_onLiftStatus);

  /// 진동을 한 번만 울리기 위한 표시
  bool _isAnnounced = false;

  /// 다 들렸을 때 커지는 비율 · 그림 한 변 · 손잡이 한 변
  static const _liftScale = 0.03;
  static const _thumbnailSize = 44.0;
  static const _handleSize = 18.0;

  /// 글 ↔ 오른쪽 끝 · ⊖ ↔ 손잡이
  static const _textToTrailing = 4.0;
  static const _removeToHandle = 10.0;

  void _onLiftStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_isAnnounced) {
      _isAnnounced = true;
      HapticFeedback.mediumImpact();
    } else if (status == AnimationStatus.dismissed) {
      _isAnnounced = false;
    }
  }

  @override
  void didUpdateWidget(RoutineGroupSheetRow old) {
    super.didUpdateWidget(old);
    if (widget.isDragging == old.isDragging) return;
    if (widget.isDragging) {
      _lift.value = 1;
    } else {
      // 놓는 순간 손을 뗀 것과 같은 모습으로 내려앉는다
      _lift.reverse();
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  /// 들린 높이에 맞춘 그림자. 눌리지 않았으면 그리지 않는다
  List<BoxShadow> _shadow(double progress) {
    if (progress == 0) return const [];
    return [
      BoxShadow(
        color: context.colors.textPrimary.withValues(alpha: 0.26 * progress),
        blurRadius: 22 * progress,
        offset: Offset(0, 8 * progress),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final routine = widget.routine;
    return AnimatedBuilder(
      animation: _lift,
      builder: (context, _) {
        final progress = _lift.value;
        return Transform.scale(
          scale: 1 + _liftScale * progress,
          child: Container(
            height: RoutineGroupSheetRow.cardHeight.h,
            padding: EdgeInsets.symmetric(horizontal: space.sm.w),
            decoration: BoxDecoration(
              color: colors.editChipBg,
              borderRadius: BorderRadius.circular(space.cardRadius.r),
              boxShadow: _shadow(progress),
            ),
            // 잡힌 줄의 민트 테두리: 손가락이 손잡이를 가려도 줄 가장자리는 보인다
            foregroundDecoration: progress == 0
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(space.cardRadius.r),
                    border: Border.all(
                      color: colors.checkDone.withValues(alpha: progress),
                      width: space.selectedBorderWidth.w,
                    ),
                  ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(space.sm.r),
                  child: SizedBox.square(
                    dimension: _thumbnailSize.w,
                    child: LibraryRoutineThumbnail(routine: routine),
                  ),
                ),
                SizedBox(width: space.sm.w),
                // 글 자리를 누르면 상세. 손잡이는 이 바깥이라 끌기와 겹치지 않는다
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.isEnabled ? widget.onTap : null,
                    child: ContentLocale(
                      language: routine.language,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typo.sheetStepTitle.copyWith(
                              color: colors.sheetTitleText,
                            ),
                          ),
                          if (routine.steps.isNotEmpty) ...[
                            SizedBox(height: space.xs.h),
                            Text(
                              context.l10n.routineGroupRowCardCount(
                                routine.steps.length,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typo.sheetStepBody.copyWith(
                                color: colors.routineTileLabel,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: _textToTrailing.w),
                if (widget.isEditing)
                  ..._editingTrailing(context, progress)
                else
                  const SettingsCardChevron(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 순서 편집 중의 오른쪽: ⊖ + 길게 눌러 잡는 손잡이
  List<Widget> _editingTrailing(BuildContext context, double progress) {
    final colors = context.colors;
    return [
      ArrangeRemoveBadge(
        onTap: widget.isEnabled ? widget.onRemove : null,
        semanticLabel: context.l10n.routineGroupSheetRemove(
          widget.routine.displayTitle,
        ),
      ),
      SizedBox(width: _removeToHandle.w),
      // 누르는 동안의 들어올림은 여기서 시작한다. 끌기 자체는 Delayed 쪽이 맡으므로 둘의 임계가 같아야 한다
      Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (widget.isEnabled) _lift.forward();
        },
        onPointerUp: (_) => _lift.reverse(),
        onPointerCancel: (_) => _lift.reverse(),
        child: ReorderableDelayedDragStartListener(
          index: widget.index,
          enabled: widget.isEnabled,
          child: Stack(
            children: [
              SvgPicture.asset(
                AppAssets.sheetReorderHandle,
                width: _handleSize.w,
                height: _handleSize.w,
              ),
              // 잡히는 만큼 민트가 위에 짙어진다 (에셋 색을 코드에 옮겨 적지 않으려고 겹친다)
              if (progress > 0)
                Opacity(
                  opacity: progress,
                  child: SvgPicture.asset(
                    AppAssets.sheetReorderHandle,
                    width: _handleSize.w,
                    height: _handleSize.w,
                    colorFilter: ColorFilter.mode(
                      colors.checkDone,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../../../shared/models/routine.dart';
import '../../data/routine_repository.dart';

/// 오늘 일과를 눌렀을 때 올라오는 시트 (Figma 956:4084, 이슈 #266).
///
/// **보는 것과 고치는 것을 나눈다.** 예전에는 일과를 누르면 곧바로 편집 화면으로
/// 넘어갔다. 그런데 보호자가 훨씬 자주 하는 일은 "오늘 어디까지 했나"를 확인하는
/// 것이지 문구를 고치는 것이 아니다. 그래서 확인은 시트에서 가볍게 하고, 고칠 때만
/// 편집 화면으로 들어간다.
///
/// **시트에서 할 수 있는 고치기는 순서 하나뿐이다.** 문구·그림·보상은 전부
/// `편집하기`로 보낸다. 여기서 이것저것 고칠 수 있게 하면 시트와 편집 화면의
/// 경계가 사라져 둘 다 어중간해진다.
class RoutineDetailSheet extends ConsumerStatefulWidget {
  const RoutineDetailSheet({super.key, required this.routine});

  final Routine routine;

  /// 시트를 띄운다. `편집하기`를 누르면 true가 돌아온다.
  ///
  /// 편집 화면으로는 **부르는 쪽이 보낸다.** 시트가 직접 화면을 밀면 시트가 뜬 채로
  /// 그 위에 화면이 얹혀, 뒤로가기를 두 번 눌러야 홈으로 나온다.
  static Future<bool?> show(BuildContext context, Routine routine) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutineDetailSheet(routine: routine),
    );
  }

  @override
  ConsumerState<RoutineDetailSheet> createState() => _RoutineDetailSheetState();
}

class _RoutineDetailSheetState extends ConsumerState<RoutineDetailSheet> {
  late List<ActionCard> _steps = List.of(widget.routine.steps);

  /// 시안 기준 시트 높이는 614/852 ≈ 0.72다. 단계가 적으면 그만큼만 쓰고,
  /// 많으면 여기까지만 커진 뒤 목록이 스크롤된다.
  static const _maxHeightRatio = 0.72;

  Future<void> _reorder(int oldIndex, int newIndex) async {
    // ReorderableListView는 아래로 옮길 때 제거 전 위치를 준다.
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final before = List.of(_steps);

    setState(() {
      final moved = _steps.removeAt(oldIndex);
      _steps.insert(to, moved);
    });

    final ok = await ref.read(routineRepositoryProvider).reorderSteps(
      widget.routine.id,
      [for (final s in _steps) s.id],
    );

    if (ok || !mounted) return;

    // 서버가 받지 못했으면 화면을 되돌린다. 화면만 바뀐 채 두면 다음에 열었을 때
    // 바꾼 적 없는 것처럼 보인다.
    setState(() => _steps = before);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('순서를 저장하지 못했어요 (E-STEP-ORDER)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;
    final maxHeight = MediaQuery.sizeOf(context).height * _maxHeightRatio;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- 고정: 핸들바 + 제목 (덤프의 `스크롤 시 fix 영역`) ---
          _Header(title: widget.routine.title),

          // --- 스크롤: 단계 + 보상 ---
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              buildDefaultDragHandles: false,
              // 기본 프록시는 시트 밖 화면 위로 떠올라 엉뚱한 자리에 그려진다.
              // 들린 카드를 제자리에서 살짝 띄우기만 한다.
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 6,
                borderRadius: BorderRadius.circular(16.r),
                child: child,
              ),
              itemCount: _steps.length,
              onReorder: _reorder,
              footer: _RewardRow(routine: widget.routine),
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Padding(
                  key: ValueKey(step.id),
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _StepRow(step: step, index: index),
                );
              },
            ),
          ),

          // --- 고정: 편집하기 (목록이 길어져도 밀려나지 않는다) ---
          Padding(
            padding: EdgeInsets.fromLTRB(
              16.w,
              space.md,
              16.w,
              MediaQuery.paddingOf(context).bottom + space.md,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 66.h,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  '편집하기',
                  style: typo.button.copyWith(color: colors.surface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 스크롤해도 남는 머리 부분.
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      // 배경이 없으면 스크롤되는 목록이 제목 뒤로 비친다 (덤프의 `스크롤 시 fix 영역`에도
      // background 사각형이 따로 있다).
      color: colors.background,
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            title,
            style: context.typo.reviewTitle.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// 단계 한 줄 — 번호 뱃지 + 제목·설명 + 완료 표시 + 순서 손잡이.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.index});

  final ActionCard step;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    // 네 색을 차례로 쓰고 다섯 번째부터 다시 처음으로 (카드는 최대 10장이다).
    final palette = [
      colors.stepBadge1,
      colors.stepBadge2,
      colors.stepBadge3,
      colors.stepBadge4,
    ];

    return Row(
      children: [
        Container(
          width: 40.w,
          height: 68.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette[index % palette.length],
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Text(
            '${index + 1}',
            style: typo.stepBadgeNumber.copyWith(color: colors.surface),
          ),
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Container(
            height: 68.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: colors.editChipBg,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.cardTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      if (step.description.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          step.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typo.cardBody.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 이룸이가 해낸 결과를 보여줄 뿐 여기서 체크하지 않는다.
                // 보호자가 대신 체크하면 "이룸이가 해냈다"는 기록이 아니게 된다.
                _CompletionMark(completed: step.completed),
                SizedBox(width: 8.w),
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(
                    Icons.drag_handle,
                    size: 24.w,
                    color: colors.textPlaceholder,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompletionMark extends StatelessWidget {
  const _CompletionMark({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? colors.checkDone : Colors.transparent,
        border: completed ? null : Border.all(color: colors.border, width: 2.w),
      ),
      child: Icon(
        Icons.check,
        size: 20.w,
        color: completed ? colors.surface : colors.border,
      ),
    );
  }
}

/// 보상 줄. **없으면 아무것도 그리지 않는다.**
///
/// 빈 칸을 두면 "보상이 없다"가 아니라 "덜 만들어졌다"로 보인다. 보상을 여기서
/// 정하게 하는 안도 검토했으나 그 부분 디자인이 아직 나오지 않아 미뤘다 (#266).
class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    if (!routine.hasReward) return const SizedBox.shrink();

    final colors = context.colors;
    final typo = context.typo;

    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 68.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.textPrimary,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text('⭐', style: TextStyle(fontSize: 24.sp)),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Container(
              height: 68.h,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: colors.editChipBg,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Text(
                // 왼쪽 별 뱃지가 이미 "보상 줄"임을 말해준다. 여기에 또 그림을
                // 넣으면 한 줄에 별이 두 번 나온다 — 시안도 글자만 그린다 (#275).
                routine.rewardText.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.cardTitle.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

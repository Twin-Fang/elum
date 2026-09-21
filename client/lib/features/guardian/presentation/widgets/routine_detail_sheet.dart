import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
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

  /// 지금 끌고 있는 줄. 끌기가 시작되면 그 줄은 목록에서 빠지고 시트 위에 뜬
  /// 사본으로 다시 그려지는데, 들린 상태를 넘겨주지 않으면 잡았다 놓는 사이에
  /// 그림자가 한 번 꺼졌다 켜진다 (#274).
  int? _draggingIndex;

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
              // 들어올림은 줄이 직접 그리므로 여기서는 자리만 잡아 준다 (#274).
              proxyDecorator: (child, index, animation) =>
                  Material(color: Colors.transparent, child: child),
              itemCount: _steps.length,
              onReorder: _reorder,
              onReorderStart: (index) => setState(() => _draggingIndex = index),
              onReorderEnd: (_) => setState(() => _draggingIndex = null),
              footer: _RewardRow(routine: widget.routine),
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Padding(
                  key: ValueKey(step.id),
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: _StepRow(
                    step: step,
                    index: index,
                    dragging: _draggingIndex == index,
                  ),
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
            style: context.typo.sheetTitle.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// 단계 한 줄 — 번호 뱃지 + 제목·설명 + 완료 표시 + 순서 손잡이.
///
/// **손잡이는 길게 눌러야 잡힌다** (#274). 닿는 즉시 끌리게 두면 목록을 스크롤하려던
/// 손가락이 손잡이를 스치는 것만으로 순서가 바뀐다. 고칠 생각이 없었는데 일과가
/// 바뀌고 서버로 전송까지 된다.
///
/// 누르고 있는 동안 줄이 **점점 떠오른다.** 예전에는 움직여야 그림자가 나타나서
/// 누르는 내내 아무 일도 없다가 갑자기 뜨는 것처럼 보였다. 다 떠오른 순간이 곧
/// 잡힌 순간이므로 진동으로 함께 알리고, 도중에 손을 떼면 제자리로 내려앉는다.
class _StepRow extends StatefulWidget {
  const _StepRow({
    required this.step,
    required this.index,
    this.dragging = false,
  });

  final ActionCard step;
  final int index;

  /// 지금 끌려가는 중인가. 끌기가 시작되면 이 줄은 시트 위의 사본으로 다시
  /// 그려지므로, 들린 상태로 시작하지 않으면 그림자가 한 번 깜빡인다.
  final bool dragging;

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow>
    with SingleTickerProviderStateMixin {
  /// 누르고 있는 정도(0~1).
  ///
  /// 길이를 [kLongPressTimeout]에 맞춘다. 이 값이 실제로 잡히는 시점과 어긋나면
  /// 다 떠오른 뒤에도 안 잡히거나, 덜 떠오른 채로 잡혀 버린다.
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: kLongPressTimeout,
    reverseDuration: AppMotion.fast,
    value: widget.dragging ? 1 : 0,
  )..addStatusListener(_onLiftStatus);

  /// 진동을 한 번만 울리기 위한 표시.
  bool _announced = false;

  /// 다 들렸을 때 커지는 비율. 그림자가 주된 신호이고 크기는 거들 뿐이라 작게 준다.
  static const _liftScale = 0.03;

  void _onLiftStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_announced) {
      _announced = true;
      HapticFeedback.mediumImpact();
    } else if (status == AnimationStatus.dismissed) {
      _announced = false;
    }
  }

  @override
  void didUpdateWidget(_StepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dragging == oldWidget.dragging) return;
    if (widget.dragging) {
      _lift.value = 1;
    } else {
      // 놓는 순간 되돌린다 — 손을 뗀 것과 같은 모습으로 내려앉는다.
      _lift.reverse();
    }
  }

  @override
  void dispose() {
    _lift.dispose();
    super.dispose();
  }

  /// 들린 높이에 맞춘 그림자. 눌리지 않았으면 아예 그리지 않는다.
  List<BoxShadow> _shadow(double t) {
    if (t == 0) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.16 * t),
        blurRadius: 18 * t,
        offset: Offset(0, 6 * t),
      ),
    ];
  }

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

    return AnimatedBuilder(
      animation: _lift,
      builder: (context, _) {
        final t = _lift.value;
        // 뱃지와 카드에 따로 그림자를 준다. 줄 전체를 한 덩어리로 감싸면
        // 둘 사이 틈까지 사각형으로 덮인다.
        final shadow = _shadow(t);

        return Transform.scale(
          scale: 1 + _liftScale * t,
          child: Row(
            children: [
              // 끌고 있는 동안에는 뱃지를 감춘다 (이슈 #296).
              //
              // **번호는 카드의 이름표가 아니라 몇 번째 자리인가를 뜻한다.** 뱃지가
              // 카드를 따라다니면 내려놓는 순간 번호가 한꺼번에 다시 매겨져,
              // 무엇을 어디로 옮겼는지 눈으로 좇기 어렵다. 카드만 떠오르게 두면
              // 왼쪽 줄은 1·2·3·4 그대로 서 있고 내용만 자리를 바꾼다.
              //
              // 자리는 남겨 둔다. 통째로 들어내면 떠오른 카드의 폭이 달라져
              // 놓을 자리를 가늠하기 어려워진다.
              Opacity(
                opacity: widget.dragging ? 0 : 1,
                child: Container(
                  width: 40.w,
                  height: 68.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette[widget.index % palette.length],
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: shadow,
                  ),
                  child: Text(
                    '${widget.index + 1}',
                    style: typo.stepBadgeNumber.copyWith(color: colors.surface),
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Container(
                  height: 68.h,
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  decoration: BoxDecoration(
                    color: colors.editChipBg,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: shadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.step.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typo.sheetStepTitle.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            if (widget.step.description.isNotEmpty) ...[
                              SizedBox(height: 2.h),
                              Text(
                                widget.step.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typo.sheetStepBody.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 이룸이가 해낸 결과를 보여줄 뿐 여기서 체크하지 않는다.
                      // 보호자가 대신 체크하면 "이룸이가 해냈다"는 기록이 아니게 된다.
                      _CompletionMark(completed: widget.step.completed),
                      SizedBox(width: 8.w),
                      // 누르는 동안의 들어올림은 여기서 시작한다. 끌기 자체는
                      // Delayed 쪽이 맡으므로 둘의 임계가 같아야 한다.
                      Listener(
                        // 아이콘 글리프에만 의존하면 빈틈이 생긴다. 손잡이는
                        // 24px이라 그러잖아도 좁으므로 영역 전체로 받는다.
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) => _lift.forward(),
                        onPointerUp: (_) => _lift.reverse(),
                        onPointerCancel: (_) => _lift.reverse(),
                        child: ReorderableDelayedDragStartListener(
                          index: widget.index,
                          child: Icon(
                            Icons.drag_handle,
                            size: 24.w,
                            color: colors.textPlaceholder,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompletionMark extends StatelessWidget {
  const _CompletionMark({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 시안(`채크_라운드` 726:4881)은 두 상태를 이렇게 나눈다.
    // 미완료도 투명이 아니라 배경색으로 칠하고 테두리를 따로 둔다 — 투명하게 두면
    // 카드 위에서 동그라미가 사라져 "누를 곳"으로 읽히지 않는다.
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? colors.checkDone : colors.background,
        border: completed
            ? null
            : Border.all(color: colors.checkIdleBorder, width: 2.w),
      ),
      child: Icon(
        Icons.check,
        size: 22.w,
        color: completed ? colors.surface : colors.checkIdleBorder,
      ),
    );
  }
}

/// 보상 줄. **없으면 아무것도 그리지 않는다.**
///
/// 빈 칸을 두면 "보상이 없다"가 아니라 "덜 만들어졌다"로 보인다. 보상을 여기서
/// 정하게 하는 안도 검토했으나 그 부분 디자인이 아직 나오지 않아 미뤘다 (#266).
///
/// **뱃지 + 카드로 둔다** (#295). 전에는 별 뱃지를 빼고 `다 하면 ○○`이라는 말로
/// 대신했다 (#275) — 별이 이룸이가 일과를 끝냈을 때의 연출과 뜻이 겹친다고 봤다.
/// 그 뒤에 나온 시안(956:4084)이 검은 뱃지에 별을 넣어 단계와 같은 짜임으로
/// 그렸고, 시안이 나중 판단이라 그쪽을 따른다. 뱃지 색과 별이 이미 "이건 단계가
/// 아니다"를 말해 주므로 `다 하면`이라는 말은 뺀다.
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
          // 단계 번호 자리에 검은 뱃지를 둔다. 폭이 같아 줄이 나란히 서고,
          // 색과 별로 "이건 단계가 아니라 보상"이 읽힌다 (Figma 963:4423).
          Container(
            width: 40.w,
            height: 68.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.rewardBadgeTop, colors.rewardBadgeBottom],
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: SvgPicture.asset(
              AppAssets.rewardBadgeStar,
              width: 25.w,
              height: 24.w,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Container(
              height: 68.h,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              decoration: BoxDecoration(
                color: colors.editChipBg,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                routine.rewardText.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.sheetStepTitle.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

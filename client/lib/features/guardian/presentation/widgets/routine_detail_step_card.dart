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
import '../../../../shared/models/action_card.dart';

/// 단계 카드 — 제목·설명 + 완료 표시 + 순서 손잡이. 순서 바꾸기는 이 카드만 옮긴다.
///
/// **손잡이는 길게 눌러야 잡힌다**. 닿는 즉시 끌리게 두면 목록을 스크롤하려던
/// 손가락이 손잡이를 스치는 것만으로 순서가 바뀐다. 고칠 생각이 없었는데 일과가
/// 바뀌고 서버로 전송까지 된다.
///
/// 누르고 있는 동안 줄이 **점점 떠오른다.** 움직여야 그림자가 나타나면
/// 누르는 내내 아무 일도 없다가 갑자기 뜨는 것처럼 보인다. 다 떠오른 순간이 곧
/// 잡힌 순간이므로 진동으로 함께 알리고, 도중에 손을 떼면 제자리로 내려앉는다.
class RoutineDetailStepCard extends StatefulWidget {
  const RoutineDetailStepCard({
    super.key,
    required this.step,
    required this.index,
    this.language = 'ko',
    this.dragging = false,
    this.reorderable = true,
    this.onOpen,
  });

  final ActionCard step;
  final int index;

  /// 카드 제목·설명의 언어(일과 언어).
  final String language;

  /// 글 자리를 눌렀을 때 — 카드를 크게 연다. 손잡이와 체크는 따로 받는다.
  final VoidCallback? onOpen;

  /// 지금 끌려가는 중인가. 끌기가 시작되면 이 카드는 시트 위의 사본으로 다시
  /// 그려지므로, 들린 상태로 시작하지 않으면 그림자가 한 번 깜빡인다.
  final bool dragging;

  /// 순서 바꾸는 손잡이를 그릴지. 지난 일과는 그리지 않는다 (시안 980:4777).
  final bool reorderable;

  @override
  State<RoutineDetailStepCard> createState() => _RoutineDetailStepCardState();
}

class _RoutineDetailStepCardState extends State<RoutineDetailStepCard>
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
  void didUpdateWidget(RoutineDetailStepCard oldWidget) {
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
        // 카드가 옅은 회색이라 알파가 낮으면 배경에 묻힌다
        color: context.colors.textPrimary.withValues(alpha: 0.26 * t),
        blurRadius: 22 * t,
        offset: Offset(0, 8 * t),
      ),
    ];
  }

  /// 잡힌 카드의 테두리. 눌리지 않았으면 그리지 않는다.
  ///
  /// 손가락이 18px 손잡이를 가려도 카드 가장자리는 보인다. 그림자·크기와 달리
  /// 색은 "지금 이 카드를 쥐고 있다"를 한눈에 알린다.
  /// 배경 테두리로 그리면 안쪽 여백이 밀려 글이 움직이므로 위에 덧그린다.
  BoxDecoration? _outline(double t, Color color) {
    if (t == 0) return null;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(
        color: color.withValues(alpha: t),
        width: 2.w,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return AnimatedBuilder(
      animation: _lift,
      builder: (context, _) {
        final t = _lift.value;
        final shadow = _shadow(t);

        // 번호 뱃지는 여기 없다 — 왼쪽 칸에 따로 서 있어 들리지 않는다.
        return Transform.scale(
          scale: 1 + _liftScale * t,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 68.h,
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  decoration: BoxDecoration(
                    color: colors.editChipBg,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: shadow,
                  ),
                  foregroundDecoration: _outline(t, colors.checkDone),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          // 글자 사이 빈 곳도 눌리게 한다. 손잡이는 이 바깥이라 끌기와 겹치지 않는다.
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onOpen,
                          child: Semantics(
                            button: widget.onOpen != null,
                            hint: context.l10n.routineDetailOpenHint,
                            child: ContentLocale(
                              language: widget.language,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.step.displayTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    // 시안(963:4236)은 순검정이다. 앱 본문색(#242634)이
                                    // 아니다 — 시트 제목과 같은 토큰을 쓴다.
                                    style: typo.sheetStepTitle.copyWith(
                                      color: colors.sheetTitleText,
                                    ),
                                  ),
                                  if (widget.step.description.isNotEmpty) ...[
                                    // 시안 제목 y15(16 높이) · 설명 y39 → 사이 8
                                    SizedBox(height: 8.h),
                                    Text(
                                      widget.step.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      // 시안의 `sub_color`(#74757D). 일과 타일 설명과 같은
                                      // 값이라 토큰을 함께 쓴다 — 디자이너가 한 변수로
                                      // 두었으므로 한쪽만 바뀌어서는 안 된다.
                                      // `textSecondary`(#898B98)는 다른 자리의 색이다.
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
                      ),
                      // 시안(963:4239)은 글 오른쪽 끝(227)과 체크(231) 사이가 4다.
                      SizedBox(width: 4.w),
                      // 이룸이가 해낸 결과를 보여줄 뿐 여기서 체크하지 않는다.
                      // 보호자가 대신 체크하면 "이룸이가 해냈다"는 기록이 아니게 된다.
                      _CompletionMark(completed: widget.step.completed),
                      // 손잡이가 없으면 그 자리의 여백도 없다 (시안 980:4777)
                      if (widget.reorderable) ...[
                        // 시안 체크 끝(271) → 손잡이(281) 사이 10
                        SizedBox(width: 10.w),
                        // 누르는 동안의 들어올림은 여기서 시작한다. 끌기 자체는
                        // Delayed 쪽이 맡으므로 둘의 임계가 같아야 한다.
                        Listener(
                          // 아이콘 글리프에만 의존하면 빈틈이 생긴다. 손잡이는
                          // 18px이라 그러잖아도 좁으므로 영역 전체로 받는다.
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) => _lift.forward(),
                          onPointerUp: (_) => _lift.reverse(),
                          onPointerCancel: (_) => _lift.reverse(),
                          child: ReorderableDelayedDragStartListener(
                            index: widget.index,
                            child: Stack(
                              children: [
                                // **`Icons.drag_handle`이 아니다.** 그건 줄이 둘인데
                                // 시안(`963:4240` 순서변경)은 셋이고 색도 `#CACACA`로
                                // 더 진하다. 눌리지 않았을 때는 에셋 색 그대로다.
                                SvgPicture.asset(
                                  AppAssets.sheetReorderHandle,
                                  width: 18.w,
                                  height: 18.w,
                                ),
                                // 잡히는 만큼 민트가 위에 짙어진다. 에셋 색을
                                // 코드에 옮겨 적지 않으려고 값을 섞지 않고 겹친다.
                                if (t > 0)
                                  Opacity(
                                    opacity: t,
                                    child: SvgPicture.asset(
                                      AppAssets.sheetReorderHandle,
                                      width: 18.w,
                                      height: 18.w,
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
                      ],
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

  /// 시안(956:4084 `채크_라운드`) — 원 40 · 안의 체크 21.82×16.26.
  /// 원본 컴포넌트가 20 기준 10.91×8.13 이라 그 비율 그대로다.
  static const _size = 40.0;
  static const _markW = 21.82;
  static const _markH = 16.26;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 시안(`채크_라운드` 726:4881)은 두 상태를 이렇게 나눈다.
    // 미완료도 투명이 아니라 배경색으로 칠하고 테두리를 따로 둔다 — 투명하게 두면
    // 카드 위에서 동그라미가 사라져 "누를 곳"으로 읽히지 않는다.
    return Container(
      width: _size.w,
      height: _size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? colors.checkDone : colors.background,
        border: completed
            ? null
            : Border.all(color: colors.checkIdleBorder, width: 2.w),
      ),
      // **글리프가 아니라 에셋이다.** `Icons.check` 는 정사각형이라 시안의
      // 가로로 긴 체크와 모양이 다르다 (client/CLAUDE.md §2).
      child: SvgPicture.asset(
        AppAssets.iconCheckMark,
        width: _markW.w,
        height: _markH.w,
        colorFilter: ColorFilter.mode(
          completed ? colors.surface : colors.checkIdleBorder,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../../../shared/models/routine.dart';
import '../../data/routine_repository.dart';
import 'step_card_viewer.dart';

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
/// 시트를 닫으며 부르는 쪽에 알리는 것.
///
/// 시트는 **화면을 직접 밀지 않는다.** 시트가 뜬 채로 그 위에 화면이 얹히면
/// 뒤로가기를 두 번 눌러야 홈으로 나온다.
enum RoutineSheetAction {
  /// 오늘 일과 — 검토 화면으로 보낸다.
  edit,

  /// 지난 일과 — 오늘 날짜로 복제한다.
  rerun,
}

class RoutineDetailSheet extends ConsumerStatefulWidget {
  const RoutineDetailSheet({
    super.key,
    required this.routine,
    this.isPast = false,
    this.isFinished = false,
  });

  final Routine routine;

  /// 지난 일과인가 (시안 `980:4777`).
  ///
  /// **지나간 것은 고치지 않는다.** 고쳐 봐야 어제 일과가 바뀔 뿐 오늘 할 일이
  /// 생기지 않는다. 그래서 시안은 버튼을 `일과 다시하기`로 두고 순서 바꾸는
  /// 손잡이도 그리지 않는다 — 그날의 결과를 그대로 보여 주는 화면이다.
  final bool isPast;

  /// 이룸이가 다 끝낸 오늘 일과인가 (#534).
  ///
  /// **끝낸 일과는 고치지 않는다.** 이룸이 화면은 다 끝낸 일과를 다시 그리지 않아
  /// 보호자가 고쳐도 아무 데도 반영되지 않는다. 버튼을 숨기지 않고 눌리지 않게 두어
  /// 왜 못 고치는지 버튼 글자로 알린다. 같은 휴대폰의 기기 기록까지 보는 쪽이 판단해 넘긴다.
  final bool isFinished;

  /// 시트를 띄운다. 눌린 버튼이 [RoutineSheetAction]으로 돌아온다.
  static Future<RoutineSheetAction?> show(
    BuildContext context,
    Routine routine, {
    bool isPast = false,
    bool isFinished = false,
  }) {
    return showModalBottomSheet<RoutineSheetAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoutineDetailSheet(
        routine: routine,
        isPast: isPast,
        isFinished: isFinished,
      ),
    );
  }

  @override
  ConsumerState<RoutineDetailSheet> createState() => _RoutineDetailSheetState();
}

class _RoutineDetailSheetState extends ConsumerState<RoutineDetailSheet> {
  late List<ActionCard> _steps = List.of(widget.routine.steps);

  /// 시트 높이. 시안(956:4084) 기준 614/852 ≈ 0.72다.
  ///
  /// **내용과 무관하게 이 높이를 지킨다** (#316). 전에는 최대치로만 두어 단계가
  /// 적으면 시트가 오그라들었는데, 그러면 **열 때마다 시트 윗변이 달라져**
  /// 보호자가 매번 다른 화면을 본다. 윗변이 밀리면 안의 모든 줄이 함께 밀린다.
  ///
  /// 단계가 많으면 지금처럼 목록이 안에서 스크롤된다.
  static const _heightRatio = 0.72;

  /// 지금 끌고 있는 줄. 끌기가 시작되면 그 줄은 목록에서 빠지고 시트 위에 뜬
  /// 사본으로 다시 그려지는데, 들린 상태를 넘겨주지 않으면 잡았다 놓는 사이에
  /// 그림자가 한 번 꺼졌다 켜진다 (#274).
  int? _draggingIndex;

  /// 오늘 일과인데 이룸이가 다 끝냈다 — 하단 버튼을 막는다 (#534).
  bool get _finishedToday => !widget.isPast && widget.isFinished;

  /// 이 시트에서 고칠 수 있는가 — 남이 만든 일과는 보기만 한다 (다중 보호자 #362 · E46).
  /// 지난 일과는 원래 고치지 않는다([RoutineDetailSheet.isPast]). 다 끝낸 일과도 같다 (#534).
  bool get _canEdit =>
      !widget.isPast && !widget.isFinished && widget.routine.isEditableByMe;

  Future<void> _reorder(int oldIndex, int newIndex) async {
    // ReorderableListView는 아래로 옮길 때 제거 전 위치를 준다.
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final before = List.of(_steps);

    setState(() {
      final moved = _steps.removeAt(oldIndex);
      _steps.insert(to, moved);
    });

    final failure = await ref.read(routineRepositoryProvider).reorderSteps(
      widget.routine.id,
      [for (final s in _steps) s.id],
    );

    if (failure == null || !mounted) return;

    // 서버가 받지 못했으면 화면을 되돌린다. 화면만 바뀐 채 두면 다음에 열었을 때
    // 바꾼 적 없는 것처럼 보인다.
    setState(() => _steps = before);
    showFailure(
      context,
      failure,
      title: context.l10n.routineDetailReorderFailedTitle,
      fallback: context.l10n.routineDetailReorderFailedFallback,
      fallbackCode: 'E-STEP-ORDER',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;
    final height = MediaQuery.sizeOf(context).height * _heightRatio;

    // 떠 있는 버튼 자리. 시안(963:4448) 버튼은 y492~558 이고 시트가 614 라
    // **아래가 56**이다. 안전영역을 더하지 않는다 — 시트가 이미 화면 바닥까지
    // 내려와 있고 시안의 56 안에 홈 인디케이터 자리가 들어 있다.
    final buttonBottom = 56.h;
    final buttonHeight = 66.h;

    return Container(
      height: height,
      // **자식까지 둥근 모양으로 자른다.** `decoration`의 라운드는 배경만 둥글게
      // 칠할 뿐 자식을 자르지 않는다. 바로 아래 헤더가 배경색을 전체 폭에 깔기
      // 때문에, 자르지 않으면 그 사각형이 둥근 모서리를 덮어 상단이 각져 보인다.
      // 시안(`980:4891`)은 헤더 배경 자체에 `[20,20,0,0]`을 준다 (#345).
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      // **버튼은 목록 위에 떠 있다** (#434). 전에는 목록 아래에 버튼 칸을 따로
      // 잘라 두어 목록이 버튼 위에서 끝났다. 시안은 버튼을 시트 바닥 위에 띄우고
      // 목록이 그 뒤로 지나가게 그렸다.
      child: Stack(
        children: [
          Column(
            children: [
              // --- 고정: 핸들바 + 제목 (덤프의 `스크롤 시 fix 영역`) ---
              _Header(
                title: widget.routine.title,
                language: widget.routine.language,
                // 남이 만든 일과면 누가 만들었는지 먼저 말한다 — 왜 고칠 수 없는지의 답이다.
                caption: widget.isPast
                    ? null
                    : widget.routine.foreignCreatorLabel,
              ),

              // --- 스크롤: 단계 + 보상 ---
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      // 시안(956:4084) 헤더가 68 에서 끝나고 첫 단계가 76 에서 시작한다.
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                      // **번호 칸과 카드 칸을 나란히 따로 둔다** (#434).
                      //
                      // 전에는 번호와 카드를 한 줄로 묶어, 오래 누르면 번호까지 들리고
                      // 끄는 동안 번호가 카드를 따라 미끄러졌다. 번호는 몇 번째 자리인가를
                      // 뜻하므로 제자리에 두고 **카드만** 순서 바꾸기에 올린다. 시안도
                      // 번호(`1번`~`4번`, x=16)와 카드 묶음(`행동단계`, x=60)을 따로 그렸다.
                      //
                      // 한 스크롤 안에 두어야 같이 스크롤되고, 끌면서 가장자리에 닿았을 때의
                      // 자동 스크롤도 이 목록 하나로 돈다.
                      sliver: SliverCrossAxisGroup(
                        slivers: [
                          SliverConstrainedCrossAxis(
                            // 뱃지 40 + 카드와의 틈 4
                            maxExtent: 44.w,
                            sliver: SliverList.builder(
                              itemCount: _steps.length,
                              itemBuilder: (context, index) => Padding(
                                padding: EdgeInsets.only(
                                  right: 4.w,
                                  bottom: 8.h,
                                ),
                                child: _StepBadge(index: index),
                              ),
                            ),
                          ),
                          SliverReorderableList(
                            // 기본 프록시는 시트 밖 화면 위로 떠올라 엉뚱한 자리에 그려진다.
                            // 들어올림은 카드가 직접 그리므로 여기서는 자리만 잡아 준다 (#274).
                            proxyDecorator: (child, index, animation) =>
                                Material(
                                  color: Colors.transparent,
                                  child: child,
                                ),
                            itemCount: _steps.length,
                            // 지난 일과는 자리를 바꿔도 의미가 없으므로 받기만 하고 버린다.
                            // 남이 만든 일과도 카드 순서는 만든 사람의 몫이라 같다.
                            onReorder: _canEdit ? _reorder : (_, _) {},
                            onReorderStart: (index) =>
                                setState(() => _draggingIndex = index),
                            onReorderEnd: (_) =>
                                setState(() => _draggingIndex = null),
                            itemBuilder: (context, index) {
                              final step = _steps[index];
                              // **전역 키로 한 번 더 감싼다.** 끌기가 시작되면 목록은 이
                              // 카드를 빼고 시트 위의 사본으로 다시 그린다. 전역 키가 없으면
                              // 그때 카드 상태가 버려져, 손을 떼는 순간 이미 사라진 들어올림
                              // 애니메이션을 되돌리려다 오류가 난다. `ReorderableListView`는
                              // 이 일을 안에서 해 주지만 `SliverReorderableList`는 하지 않는다.
                              return KeyedSubtree(
                                key: ValueKey(step.id),
                                child: KeyedSubtree(
                                  key: _StepItemKey(step.id, this),
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: _StepCard(
                                      step: step,
                                      index: index,
                                      language: widget.routine.language,
                                      dragging: _draggingIndex == index,
                                      // 손잡이를 아예 그리지 않는다 (시안 980:4777)
                                      reorderable: _canEdit,
                                      // 카드를 눌러 크게 본다 (시안 1274:8864, #495)
                                      onOpen: () => StepCardViewer.show(
                                        context,
                                        cards: _steps,
                                        initialIndex: index,
                                        routineId: widget.routine.id,
                                        language: widget.routine.language,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SliverPadding(
                      // 아래 여백은 떠 있는 버튼 높이만큼 더 준다. 단계가 많아 끝까지
                      // 스크롤했을 때 마지막 보상 줄이 버튼에 가리면 안 된다.
                      // 단계가 네 개 이하면 스크롤이 생기지 않아 시안 자리 그대로다.
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        0,
                        16.w,
                        buttonBottom + buttonHeight + space.md,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _RewardRow(routine: widget.routine),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // --- 떠 있는: 편집하기 · 다시하기 (목록이 길어져도 밀려나지 않는다) ---
          // 뒤로 지나가는 목록을 흐리게 가리는 처리는 넣지 않는다 — 시안에 없다.
          // 남이 만든 일과는 버튼이 없다 — 편집하기를 눌러도 서버가 403 으로 막는다.
          if (widget.isPast || widget.routine.isEditableByMe)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: buttonBottom,
              height: buttonHeight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.textPrimary,
                  disabledBackgroundColor: colors.buttonDisabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                // 다 끝낸 오늘 일과는 눌리지 않는다 (#534). 지난 일과의 `다시하기`는 그대로 둔다.
                onPressed: _finishedToday
                    ? null
                    : () => Navigator.of(context).pop(
                        widget.isPast
                            ? RoutineSheetAction.rerun
                            : RoutineSheetAction.edit,
                      ),
                child: Text(
                  widget.isPast
                      ? context.l10n.routineDetailRerun
                      : _finishedToday
                      ? context.l10n.routineDetailFinishedToday
                      : context.l10n.routineDetailEdit,
                  style: typo.sheetActionLabel.copyWith(
                    color: _finishedToday
                        ? colors.buttonDisabledText
                        : colors.surface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 단계 카드의 전역 키. 같은 단계면 같은 키가 되도록 id 와 시트 상태로 비교한다
/// (`ReorderableListView` 내부 키와 같은 방식).
@optionalTypeArgs
class _StepItemKey extends GlobalObjectKey {
  const _StepItemKey(this.id, this.sheet) : super(id);

  final String id;
  final State sheet;

  @override
  bool operator ==(Object other) =>
      other is _StepItemKey && other.id == id && other.sheet == sheet;

  @override
  int get hashCode => Object.hash(id, sheet);
}

/// 스크롤해도 남는 머리 부분.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.language, this.caption});

  final String title;

  /// 제목(일과 글)의 언어. 아래 caption 은 화면 문구라 따르지 않는다.
  final String language;

  /// 제목 아래 한 줄 (`엄마가 만든 일과예요`). 없으면 자리도 없다 — 내 일과의 시트는 그대로다.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      // 배경이 없으면 스크롤되는 목록이 제목 뒤로 비친다 (덤프의 `스크롤 시 fix 영역`에도
      // background 사각형이 따로 있다).
      color: colors.background,
      // 시안(980:5146) 헤더는 68 높이다 — 손잡이 16 · 제목 40~60 · 아래 8.
      // 아래를 16 으로 두면 헤더가 76 이 되어 목록 전체가 8 씩 밀린다.
      //
      // 위는 **12**다. 16 으로 두어 손잡이가 시안보다 4 내려가 있었다 (#297).
      // 아래 제목까지의 간격에서 그 4 를 되돌려 주므로 목록은 제자리다.
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: colors.sheetHandle,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          // 위 여백에서 줄인 4 를 여기서 되돌린다 — 손잡이만 올라가고
          // 제목·목록은 시안 자리에 그대로 있어야 한다 (#297).
          SizedBox(height: 24.h),
          ContentLocale(
            language: language,
            child: Text(
              title,
              style: context.typo.sheetTitle.copyWith(
                color: colors.sheetTitleText,
              ),
            ),
          ),
          if (caption != null) ...[
            SizedBox(height: 4.h),
            Text(
              caption!,
              style: context.typo.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// 단계 번호 뱃지. **순서를 바꿔도 움직이지 않는다** (#434).
///
/// 번호는 카드의 이름표가 아니라 몇 번째 자리인가를 뜻한다(#296). 그래서 카드
/// 목록과 떼어 왼쪽 칸에 세워 두고, 끌기에도 들어올림에도 끼지 않는다. 카드를
/// 옮기면 왼쪽 줄은 1·2·3·4 그대로 서 있고 오른쪽 내용만 자리를 바꾼다.
class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 네 색을 차례로 쓰고 다섯 번째부터 다시 처음으로 (카드는 최대 10장이다).
    final palette = [
      colors.stepBadge1,
      colors.stepBadge2,
      colors.stepBadge3,
      colors.stepBadge4,
    ];

    return Container(
      width: 40.w,
      height: 68.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette[index % palette.length],
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        '${index + 1}',
        style: context.typo.stepBadgeNumber.copyWith(color: colors.surface),
      ),
    );
  }
}

/// 단계 카드 — 제목·설명 + 완료 표시 + 순서 손잡이. 순서 바꾸기는 이 카드만 옮긴다.
///
/// **손잡이는 길게 눌러야 잡힌다** (#274). 닿는 즉시 끌리게 두면 목록을 스크롤하려던
/// 손가락이 손잡이를 스치는 것만으로 순서가 바뀐다. 고칠 생각이 없었는데 일과가
/// 바뀌고 서버로 전송까지 된다.
///
/// 누르고 있는 동안 줄이 **점점 떠오른다.** 예전에는 움직여야 그림자가 나타나서
/// 누르는 내내 아무 일도 없다가 갑자기 뜨는 것처럼 보였다. 다 떠오른 순간이 곧
/// 잡힌 순간이므로 진동으로 함께 알리고, 도중에 손을 떼면 제자리로 내려앉는다.
class _StepCard extends StatefulWidget {
  const _StepCard({
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

  /// 글 자리를 눌렀을 때 — 카드를 크게 연다 (#495). 손잡이와 체크는 따로 받는다.
  final VoidCallback? onOpen;

  /// 지금 끌려가는 중인가. 끌기가 시작되면 이 카드는 시트 위의 사본으로 다시
  /// 그려지므로, 들린 상태로 시작하지 않으면 그림자가 한 번 깜빡인다.
  final bool dragging;

  /// 순서 바꾸는 손잡이를 그릴지. 지난 일과는 그리지 않는다 (시안 980:4777).
  final bool reorderable;

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard>
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
  void didUpdateWidget(_StepCard oldWidget) {
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

    return AnimatedBuilder(
      animation: _lift,
      builder: (context, _) {
        final t = _lift.value;
        final shadow = _shadow(t);

        // 번호 뱃지는 여기 없다 — 왼쪽 칸에 따로 서 있어 들리지 않는다 (#434).
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
                            child: SvgPicture.asset(
                              // **`Icons.drag_handle`이 아니다.** 그건 줄이 둘인데
                              // 시안(`963:4240` 순서변경)은 셋이고 색도 `#CACACA`로
                              // 더 진하다. 색은 에셋에 들어 있으니 덧칠하지 않는다.
                              AppAssets.sheetReorderHandle,
                              width: 18.w,
                              height: 18.w,
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

/// 보상 줄. **정하지 않았어도 그린다** (#308).
///
/// 전에는 없으면 줄째 숨겼다 — 빈 칸이 "덜 만들어졌다"로 보인다고 봤기 때문이다.
/// 시안(980:5174)은 그 걱정을 다르게 푼다. 빈 칸을 두는 대신 **없다고 말하고**
/// 별을 흐리게 해 채울 수 있는 자리임을 보여준다. 줄째 없애면 보상을 넣을 수
/// 있다는 것조차 보이지 않는다.
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
    final colors = context.colors;
    final typo = context.typo;
    // 보상을 아직 정하지 않았어도 줄은 그린다 (#308). 줄째 없애면 보상을 넣을 수
    // 있다는 것조차 보이지 않는다. 시안(980:5174)은 **글자로** 알린다 —
    // 빈 칸이 아니라 "없어요"라고 말해 준다.
    final hasReward = routine.hasReward;

    final rewardText = Text(
      hasReward ? routine.rewardText.trim() : context.l10n.routineDetailNoReward,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: typo.sheetStepTitle.copyWith(
        color: hasReward ? colors.textPrimary : colors.rewardEmptyLabel,
      ),
    );

    // **위 여백을 주지 않는다.** 단계 줄마다 아래 8 이 붙어 있어 여기서 또 주면
    // 마지막 단계와 보상 사이만 16 이 된다 (시안은 8).
    return Padding(
      padding: EdgeInsets.zero,
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
            // 정하지 않았으면 별을 흐리게 — 채울 수 있는 자리임을 보여준다.
            // **별은 흐리게 하지 않는다.** 시안(`980:5174`)의 별은 보상이 없을
            // 때도 선명하다 — 흐리게 한 건 시안을 잘못 읽은 것이었다 (#297).
            // 비었다는 것은 **글자가** 말해 준다.
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
              // 보상 글은 일과 언어, 비었다는 안내는 화면 문구라 따로 둔다
              child: hasReward
                  ? ContentLocale(language: routine.language, child: rewardText)
                  : rewardText,
            ),
          ),
        ],
      ),
    );
  }
}

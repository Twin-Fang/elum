import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import '../../../../shared/models/routine.dart';
import 'routine_detail_header.dart';
import 'routine_detail_reward_row.dart';
import 'routine_detail_step_badge.dart';
import 'routine_detail_step_card.dart';
import 'step_card_viewer.dart';
import '../../application/guardian_home_controller.dart';
import 'routine_reminder_row.dart';

// 알림 줄 노출 여부: 알림 설계 확정 전까지 false (코드는 유지)
const _isReminderRowVisible = false;

/// 오늘 일과를 눌렀을 때 올라오는 시트 (Figma 956:4084).
///
/// **보는 것과 고치는 것을 나눈다.** 일과를 누르면 곧바로 편집 화면으로
/// 넘기지 않는다. 보호자가 훨씬 자주 하는 일은 "오늘 어디까지 했나"를 확인하는
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

  /// 일과관리 원본 — 오늘 이룸이에게 보낸다 (#805).
  send,
}

class RoutineDetailSheet extends ConsumerStatefulWidget {
  const RoutineDetailSheet({
    super.key,
    required this.routine,
    this.isPast = false,
    this.isFinished = false,
    this.isLibrary = false,
  });

  final Routine routine;

  /// 일과관리 칸에서 연 원본인가 (#805). 아래 버튼이 `카드 고치기` · `오늘 보내기` 둘이 된다.
  final bool isLibrary;

  /// 지난 일과인가 (시안 `980:4777`).
  ///
  /// **지나간 것은 고치지 않는다.** 고쳐 봐야 어제 일과가 바뀔 뿐 오늘 할 일이
  /// 생기지 않는다. 그래서 시안은 버튼을 `일과 다시하기`로 두고 순서 바꾸는
  /// 손잡이도 그리지 않는다 — 그날의 결과를 그대로 보여 주는 화면이다.
  final bool isPast;

  /// 이룸이가 다 끝낸 오늘 일과인가.
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
    bool isLibrary = false,
  }) {
    return showElumSheet<RoutineSheetAction>(
      context: context,
      // 가로 태블릿은 목록을 보면서 상세를 보도록 오른쪽 옆 패널 (#789)
      isSidePanelOnWideTablet: true,
      builder: (_) => RoutineDetailSheet(
        routine: routine,
        isPast: isPast,
        isFinished: isFinished,
        isLibrary: isLibrary,
      ),
    );
  }

  @override
  ConsumerState<RoutineDetailSheet> createState() => _RoutineDetailSheetState();
}

class _RoutineDetailSheetState extends ConsumerState<RoutineDetailSheet> {
  // 일과관리 원본은 보관본이라 예전에 한 체크를 보이지 않는다 — 오늘 보내면 새로 시작한다
  late List<ActionCard> _steps = [
    for (final step in widget.routine.steps)
      widget.isLibrary ? step.copyWith(completed: false) : step,
  ];

  /// 시트 높이. 시안(956:4084) 기준 614/852 ≈ 0.72다.
  ///
  /// **내용과 무관하게 이 높이를 지킨다**. 최대치로만 두면 단계가
  /// 적을 때 시트가 오그라들어 **열 때마다 시트 윗변이 달라지고**
  /// 보호자가 매번 다른 화면을 본다. 윗변이 밀리면 안의 모든 줄이 함께 밀린다.
  ///
  /// 단계가 많으면 지금처럼 목록이 안에서 스크롤된다.
  static const _heightRatio = 0.72;

  /// 떠 있는 버튼 뒤 그라데이션 높이 (시안 1274:8309, 시트 바닥에서 위로)
  static const _buttonFadeHeight = 138.0;

  /// 지금 끌고 있는 줄. 끌기가 시작되면 그 줄은 목록에서 빠지고 시트 위에 뜬
  /// 사본으로 다시 그려지는데, 들린 상태를 넘겨주지 않으면 잡았다 놓는 사이에
  /// 그림자가 한 번 꺼졌다 켜진다.
  int? _draggingIndex;

  /// 오늘 일과인데 이룸이가 다 끝냈다 — 하단 버튼을 막는다.
  bool get _finishedToday => !widget.isPast && widget.isFinished;

  /// 이 시트에서 고칠 수 있는가 — 남이 만든 일과는 보기만 한다.
  /// 지난 일과는 원래 고치지 않는다([RoutineDetailSheet.isPast]). 다 끝낸 일과도 같다.
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

    final failure = await ref.read(guardianHomeControllerProvider).reorderSteps(
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

    return ElumSheetSurface(
      height: height,
      // 손잡이는 헤더 흐름 안에 둔다 — 헤더 배경이 손잡이 아래로 깔려야 한다
      showHandle: false,
      // **자식까지 둥근 모양으로 자른다.** `decoration`의 라운드는 배경만 둥글게
      // 칠할 뿐 자식을 자르지 않는다. 바로 아래 헤더가 배경색을 전체 폭에 깔기
      // 때문에, 자르지 않으면 그 사각형이 둥근 모서리를 덮어 상단이 각져 보인다.
      // 시안(`980:4891`)은 헤더 배경 자체에 `[20,20,0,0]`을 준다.
      clipBehavior: Clip.antiAlias,
      // **버튼은 목록 위에 떠 있다**. 버튼 칸을 따로 자르면
      // 목록이 버튼 위에서 끝난다. 시안은 버튼을 시트 바닥 위에 띄우고
      // 목록이 그 뒤로 지나가게 그렸다.
      child: Stack(
        children: [
          Column(
            children: [
              // --- 고정: 핸들바 + 제목 (덤프의 `스크롤 시 fix 영역`) ---
              RoutineDetailHeader(
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
                      // **번호 칸과 카드 칸을 나란히 따로 둔다**.
                      //
                      // 한 줄로 묶으면 오래 누를 때 번호까지 들리고
                      // 끄는 동안 번호가 카드를 따라 미끄러진다. 번호는 몇 번째 자리인가를
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
                                child: RoutineDetailStepBadge(index: index),
                              ),
                            ),
                          ),
                          SliverReorderableList(
                            // 기본 프록시는 시트 밖 화면 위로 떠올라 엉뚱한 자리에 그려진다.
                            // 들어올림은 카드가 직접 그리므로 여기서는 자리만 잡아 준다.
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
                                    child: RoutineDetailStepCard(
                                      step: step,
                                      index: index,
                                      language: widget.routine.language,
                                      dragging: _draggingIndex == index,
                                      // 손잡이를 아예 그리지 않는다 (시안 980:4777)
                                      reorderable: _canEdit,
                                      // 카드를 눌러 크게 본다 (시안 1274:8864)
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
                        child: Column(
                          children: [
                            RoutineDetailRewardRow(routine: widget.routine),
                            // 일과 알림 (#777): 설계 확정 전까지 숨김. 오늘 일과만, 지난 일과는 `다시하기` 뒤 새 일과에 건다
                            if (_isReminderRowVisible && !widget.isPast) ...[
                              SizedBox(height: 8.h),
                              RoutineReminderRow(routine: widget.routine),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // --- 떠 있는: 편집하기 · 다시하기 (목록이 길어져도 밀려나지 않는다) ---
          // 남이 만든 일과는 버튼이 없다 — 편집하기를 눌러도 서버가 403 으로 막는다.
          // 일과관리 원본은 남이 만든 것이어도 보낼 수 있어 버튼을 둔다
          if (widget.isLibrary ||
              widget.isPast ||
              widget.routine.isEditableByMe) ...[
            // 버튼 뒤 배경 (시안 1274:8309): 시트 바닥 138, 투명 > 시트 배경색.
            // 버튼 뒤로 지나가는 목록 글자가 버튼과 겹쳐 읽히지 않게 흐린다. 터치는 목록으로 통과
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _buttonFadeHeight.h,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.background.withValues(alpha: 0),
                        colors.background,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: buttonBottom,
              height: buttonHeight,
              child: widget.isLibrary
                  ? _LibraryActions(isEditable: widget.routine.isEditableByMe)
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.textPrimary,
                        disabledBackgroundColor: colors.buttonDisabled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                      // 다 끝낸 오늘 일과는 눌리지 않는다. 지난 일과의 `다시하기`는 그대로 둔다.
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

/// 일과관리 원본의 아래 버튼 두 개: `카드 고치기`(보조) · `오늘 보내기`(주)
///
/// 남이 만든 원본은 고치지 못하므로 보내기 하나만 둔다 — 보내기는 누구나 할 수 있다.
class _LibraryActions extends StatelessWidget {
  const _LibraryActions({required this.isEditable});

  final bool isEditable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18.r),
    );
    final sendButton = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: colors.textPrimary,
        shape: shape,
      ),
      onPressed: () => Navigator.of(context).pop(RoutineSheetAction.send),
      child: Text(
        context.l10n.routineLibrarySendToday,
        style: typo.sheetActionLabel.copyWith(color: colors.surface),
      ),
    );
    if (!isEditable) return SizedBox.expand(child: sendButton);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.buttonNeutral,
              shape: shape,
            ),
            onPressed: () => Navigator.of(context).pop(RoutineSheetAction.edit),
            child: Text(
              context.l10n.routineLibraryEditCards,
              style: typo.sheetActionLabel.copyWith(
                color: colors.buttonNeutralText,
              ),
            ),
          ),
        ),
        SizedBox(width: context.space.xs.w),
        Expanded(flex: 3, child: sendButton),
      ],
    );
  }
}

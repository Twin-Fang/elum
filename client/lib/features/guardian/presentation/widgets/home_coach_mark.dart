import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/widgets/coach_mark_step.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/character_badge.dart';
import '../../../../core/widgets/coach_mark_overlay.dart';
import '../../application/home_coach_notifier.dart';
import 'routine_swipe_actions.dart';

/// 보호자 홈 코치마크 (Figma 코치마크 1291:10801 — 코치마크_1·2·3).
///
/// 어떤 단계를 보여줄지는 [homeCoachProvider] 가 정하고, 여기서는 그 단계를 홈의 어느
/// 위젯에 어떤 글로 연결할지만 안다. 가리킬 위젯은 홈이 [GlobalKey] 로 넘겨준다.
/// 막은 루트 오버레이에 그린다: 홈 밖(보호자 틀)의 하단 바·광고 띠·옆 메뉴까지 덮고 누름도 막는다.
class HomeCoachMark extends ConsumerStatefulWidget {
  const HomeCoachMark({
    super.key,
    required this.createKey,
    required this.swipeKey,
    required this.modeKey,
  });

  /// `새로운 일과 만들기` 버튼
  final GlobalKey createKey;

  /// 오늘 일과의 밀 수 있는 첫 줄
  final GlobalKey swipeKey;

  /// 캐릭터 배지
  final GlobalKey modeKey;

  @override
  ConsumerState<HomeCoachMark> createState() => _HomeCoachMarkState();
}

class _HomeCoachMarkState extends ConsumerState<HomeCoachMark> {
  /// 사라지는 연출이 끝날 때까지 직전 단계 목록을 들고 있는다.
  /// 상태는 닫는 순간 비워지지만 막은 부드럽게 걷혀야 한다.
  List<HomeCoachStep>? _retained;
  int _retainedIndex = 0;

  /// 늘 켜 둔다. 띄울 단계가 없으면 오버레이 쪽이 높이 0으로 그린다
  final _rootOverlay = OverlayPortalController()..show();

  /// 시안 1274:10280 — 버튼 높이 68의 절반. 알약이라 반지름이 높이의 절반이다.
  static const _pillRadius = 34.0;

  /// 시안 1291:10730 — 화살표가 배지 바닥(126)에서 3 떨어진 129 에서 시작한다.
  static const _badgeGap = 3.0;

  /// 가리키는 글과 모양 (시안 1274:10400 · 1291:10454 · 1291:10733)
  CoachMarkStep _stepFor(HomeCoachStep step, BuildContext context) {
    switch (step) {
      case HomeCoachStep.createRoutine:
        return CoachMarkStep(
          target: widget.createKey,
          message: context.l10n.homeCoachCreate,
          holeRadius: _pillRadius.h,
          // 버튼이 자기 빛(글로우)을 갖고 있다. 칼같이 오리면 그 빛이 어둡게 잘린다.
          feather: 8.w,
        );
      case HomeCoachStep.swipeRoutine:
        // 열린 줄에서 삭제·수정 두 버튼의 가운데를 가리킨다 (시안 화살표 x=305).
        // 태블릿에서는 폰 비율 열 안이라 창이 아니라 이 화면의 폭을 쓴다
        final rowWidth = MediaQuery.sizeOf(context).width - 32.w;
        final actions =
            (RoutineSwipeActions.deleteWidth +
                    RoutineSwipeActions.actionGap +
                    RoutineSwipeActions.editWidth)
                .w;
        return CoachMarkStep(
          target: widget.swipeKey,
          message: context.l10n.homeCoachSwipe,
          align: CoachMarkAlign.end,
          holeRadius: context.space.cardRadius,
          // 밀려 나간 카드가 화면 왼쪽 끝에서 잘려 보이는 것까지 밝힌다.
          bleedLeft: true,
          pointerAt: 1 - (actions / 2) / rowWidth,
          // 열린 줄은 카드 · 삭제 · 수정이 4 간격으로 서 있다. 그 틈은 어둡다 (시안 1291:10401).
          partRadius: context.space.cardRadius,
          partsOf: (row) {
            final gap = RoutineSwipeActions.actionGap.w;
            final edit = row.right - RoutineSwipeActions.editWidth.w;
            final delete = edit - gap - RoutineSwipeActions.deleteWidth.w;
            final cardRight = row.right - RoutineSwipeActions.revealWidth.w;
            return [
              Rect.fromLTRB(0, row.top, cardRight, row.bottom),
              Rect.fromLTRB(delete, row.top, edit - gap, row.bottom),
              Rect.fromLTRB(edit, row.top, row.right, row.bottom),
            ];
          },
        );
      case HomeCoachStep.switchMode:
        return CoachMarkStep(
          target: widget.modeKey,
          message: context.l10n.homeCoachSwitch,
          align: CoachMarkAlign.end,
          holeRadius: CharacterBadge.radius.w,
          // 시안의 화살표는 배지 바닥에서 3 떨어져 시작한다. 구멍을 키운 것이 아니다 —
          // 키우면 배지 바깥에 밝은 테두리가 생긴다.
          pointerGap: _badgeGap.w,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeCoachProvider);
    if (state.active) {
      _retained = state.steps;
      _retainedIndex = state.index;
    }
    final steps = _retained;
    // 오버레이 쪽 빌더는 홈 밖에서 불린다 — 홈 기준 값은 여기서 미리 만든다
    final overlay = steps == null
        ? const SizedBox.shrink()
        : _buildOverlay(context, steps, state);
    return OverlayPortal(
      controller: _rootOverlay,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (_) => overlay,
      child: const SizedBox.shrink(),
    );
  }

  /// 루트 오버레이에 올릴 막 (단계 위치는 홈 기준, 막 크기·안전영역은 화면 전체 기준)
  Widget _buildOverlay(
    BuildContext context,
    List<HomeCoachStep> steps,
    HomeCoachState state,
  ) {
    // 화면 전체 MediaQuery: 보호자 틀이 지운 아래 안전영역, 태블릿 열 대신 창 크기
    final rootContext = Overlay.of(context, rootOverlay: true).context;
    final rootMedia = MediaQuery.maybeOf(rootContext) ?? MediaQuery.of(context);
    final notifier = ref.read(homeCoachProvider.notifier);
    return MediaQuery(
      data: rootMedia,
      // Scaffold 밖이라 글 스타일을 주는 Material 이 없다
      child: Material(
        type: MaterialType.transparency,
        child: CoachMarkOverlay(
          // 단계 계산은 홈 열 기준 (밀린 줄 폭이 홈 열을 따른다)
          steps: [for (final s in steps) _stepFor(s, context)],
          index: state.active ? state.index : _retainedIndex,
          visible: state.active,
          onNext: notifier.next,
          onClose: notifier.finish,
          onDismissed: () {
            if (mounted) setState(() => _retained = null);
          },
        ),
      ),
    );
  }
}

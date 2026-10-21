import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/coach_mark_overlay.dart';
import '../../../../core/widgets/coach_mark_step.dart';
import '../../application/card_review_coach_notifier.dart';
import 'card_review_parts.dart';
import 'coach_mark_start_gate.dart';
import 'coach_demo_layers.dart';

/// 코치마크가 가리킬 버튼: `이 카드 수정` · `카드 순서 변경` · `카드 저장하기`
class CardReviewCoachKeys {
  final edit = GlobalKey();
  final reorder = GlobalKey();
  final save = GlobalKey();
}

/// 카드 검토 코치마크: 수정 > 순서 변경 > 저장 (시안 없음, 홈 코치마크 모양)
///
/// 실제 화면 위 루트 오버레이에 막을 그린다. 가리킬 버튼은 화면이 [CardReviewCoachKeys] 로 넘긴다.
/// 처음 한 번 스스로 켜고, `?` 다시 보기는 화면이 notifier 의 replay 를 부른다.
class CardReviewCoachMark extends ConsumerStatefulWidget {
  const CardReviewCoachMark({
    super.key,
    required this.keys,
    required this.cardCount,
    required this.canStart,
  });

  final CardReviewCoachKeys keys;

  /// 단계 구성에 쓴다 (1장이면 순서 변경 단계 없음)
  final int cardCount;

  /// 지금 처음 안내를 켜도 되는 화면 상태인가 (순서 변경 모드가 아님)
  final bool canStart;

  @override
  ConsumerState<CardReviewCoachMark> createState() =>
      _CardReviewCoachMarkState();
}

class _CardReviewCoachMarkState extends ConsumerState<CardReviewCoachMark>
    with CoachMarkStartGate<CardReviewCoachMark> {
  /// dispose 에서 ref 를 읽을 수 없어 미리 잡아 둔다
  late final CardReviewCoachNotifier _notifier;

  /// 사라지는 연출이 끝날 때까지 직전 단계 목록을 들고 있는다
  List<CardReviewCoachStep>? _retained;
  int _retainedIndex = 0;

  /// 늘 켜 둔다. 띄울 단계가 없으면 빈 상자를 그린다
  final _rootOverlay = OverlayPortalController()..show();

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(cardReviewCoachProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didUpdateWidget(covariant CardReviewCoachMark old) {
    super.didUpdateWidget(old);
    if (!old.canStart && widget.canStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    }
  }

  @override
  void dispose() {
    // 안내 중 화면이 사라지면(알림 탭 이동 등) 켜진 채 남지 않게 끝낸다 (빌드 밖에서)
    final notifier = _notifier;
    Future.microtask(notifier.finish);
    super.dispose();
  }

  void _maybeStart() {
    if (mounted && widget.canStart) checkCoachMarkStart();
  }

  @override
  void onCoachMarkStartReady() {
    // 기다리는 사이 순서 변경 모드로 들어갔을 수 있다
    if (widget.canStart) _notifier.maybeStart(cardCount: widget.cardCount);
  }

  /// 단계 > 가리킬 버튼과 글 (모두 누르기 시범)
  CoachMarkStep _stepFor(CardReviewCoachStep step, BuildContext context) {
    final l10n = context.l10n;
    return switch (step) {
      CardReviewCoachStep.editCard => CoachMarkStep(
        target: widget.keys.edit,
        message: l10n.cardReviewCoachEditMessage,
        holeRadius: CardReviewToolRow.buttonRadius.r,
        demoBuilder: tapDemo,
      ),
      CardReviewCoachStep.reorderCards => CoachMarkStep(
        target: widget.keys.reorder,
        message: l10n.cardReviewCoachReorderMessage,
        holeRadius: CardReviewToolRow.buttonRadius.r,
        demoBuilder: tapDemo,
      ),
      CardReviewCoachStep.save => CoachMarkStep(
        target: widget.keys.save,
        message: l10n.cardReviewCoachSaveMessage,
        holeRadius: context.space.buttonRadius.r,
        demoBuilder: tapDemo,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardReviewCoachProvider);
    if (state.isActive) {
      _retained = state.steps;
      _retainedIndex = state.index;
    }
    final steps = _retained;
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

  /// 루트 오버레이에 올릴 막 (단계 위치는 이 화면 기준, 막 크기·안전영역은 화면 전체 기준)
  Widget _buildOverlay(
    BuildContext context,
    List<CardReviewCoachStep> steps,
    CardReviewCoachState state,
  ) {
    final rootContext = Overlay.of(context, rootOverlay: true).context;
    final rootMedia = MediaQuery.maybeOf(rootContext) ?? MediaQuery.of(context);
    return MediaQuery(
      data: rootMedia,
      // Scaffold 밖이라 글 스타일을 주는 Material 이 없다
      child: Material(
        type: MaterialType.transparency,
        child: CoachMarkOverlay(
          steps: [for (final step in steps) _stepFor(step, context)],
          index: state.isActive ? state.index : _retainedIndex,
          visible: state.isActive,
          onNext: _notifier.next,
          onClose: _notifier.finish,
          onDismissed: () {
            if (mounted) setState(() => _retained = null);
          },
        ),
      ),
    );
  }
}

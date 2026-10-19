import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'child_routine_detail_tablet_body.dart';
import 'child_routine_detail_top_bar.dart';
import 'child_routine_check_button.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/layout/layout_context_ext.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import 'widgets/reward_banner.dart';
import 'widgets/child_card_page_controller.dart';
import 'widgets/child_card_pager.dart';
import '../application/child_routine_notifier.dart';
import '../../../core/haptics/child_haptics.dart';
import '../../../core/sound/child_praise_sound.dart';
import '../data/speech_service.dart';
import 'child_home_screen.dart' show childRoutinesProvider;
import '../../../core/router/pop_or_home.dart';
import '../../member/application/member_providers.dart';
import '../../../core/router/routes.dart';

/// 일과 상세 — 카드를 넘기며 체크한다 (Figma 309:3548 체크 전 / 309:3648 체크 후).
///
/// 아이 홈이 일과 **목록**이 되면서(356:5079) 카드 페이저가 이 화면으로
/// 내려왔다. 어떤 일과의 카드인지는 홈이 넘겨준다.
///
/// 아동이 직접 조작하므로 터치 타겟이 크고(88×88) 전환이 느리다.
/// 카드를 체크하면 보상 화면이 뜬다 — 단, 같은 카드를 다시 체크할 때는 뜨지 않는다.
class ChildRoutineDetailScreen extends ConsumerStatefulWidget {
  const ChildRoutineDetailScreen({super.key, required this.routine});

  final Routine routine;

  /// 체크 버튼 크기. 아동 모드 최소 64×64를 넉넉히 넘긴다.
  static const checkButtonSize = 88.0;

  /// 아동 모드 접근성 하한. 좁은 기기에서 `.w`로 줄어들어도 이 아래로 가지 않는다.
  static const minTouchTarget = 64.0;

  /// 안전영역(59) 아래 → 뒤로가기 윗변 (시안 `1197:6775` — 뒤로가기 y=67).
  static const _backTop = 8.0;

  /// 뒤로가기 상자(40) 아래(107) → 보상 칩 윗변(159).
  static const _topBarToReward = 52.0;

  /// 보상 칩 아래(207) → 카드 윗변(231).
  static const _rewardToCard = 24.0;

  /// 카드 자리 높이 (시안 333×410). 카드가 이보다 짧아도 이 자리는 유지한다.
  static const _cardBoxHeight = 410.0;

  /// 카드 자리 아래(641)에서 체크 버튼(675)까지.
  static const _cardToCheck = 34.0;

  /// 체크 버튼. 화면에 누를 것이 여럿이라 테스트가 타입만으로는 갈라내지 못한다.
  static const checkButtonKey = ValueKey('child.routine.check');

  @override
  ConsumerState<ChildRoutineDetailScreen> createState() =>
      _ChildRoutineDetailScreenState();
}

class _ChildRoutineDetailScreenState
    extends ConsumerState<ChildRoutineDetailScreen>
    with ChildCardPageControllerMixin {
  PageController get _controller => cardPageController;

  /// 태블릿 카드 안 체크 버튼 배율 (88 > 약 119)
  static const _tabletCheckScale = 1.35;

  /// 체크 순간 색종이가 터진다. `play()`가 이 duration만큼 색종이를 뿜는다.
  /// 아동 화면 최소 전환 시간(300ms) 이상으로 둔다.
  final _confetti = ConfettiController(duration: AppMotion.normal);

  /// 지금 읽고 있는 카드 id. null이면 아무것도 안 읽고 있다.
  String? _speakingId;

  /// 지금 보고 있는 카드의 id.
  ///
  /// 목록이 주기적으로 갱신되므로 보호자가 카드 순서를 바꾸면 같은 자리(순번)에 다른
  /// 카드가 올 수 있다. 이룸이가 양말을 체크하려다 가방을 체크하게 되므로, 순번이 아니라
  /// 이 id 를 따라간다.
  String? _anchorId;

  /// dispose에서 `ref`를 읽으면 "unmounted" 오류가 난다.
  /// 미리 잡아두고 정리할 때 쓴다.
  SpeechService? _speech;

  /// 현재 보고 있는 카드. 체크 버튼이 이 카드를 대상으로 한다.
  int get _currentIndex => currentCardIndex;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 뒤에 잡는다. initState에서 읽어도 되지만 일관되게 둔다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _speech = ref.read(speechServiceProvider);
      // 카드 음성 미리 받기 (누를 때 기다리지 않게)
      final routine = _routine;
      prefetchStoredSpeech(ref, routine.id, routine.steps);
    });
  }

  @override
  void dispose() {
    // 화면을 벗어나도 소리가 남으면 다음 화면까지 따라온다
    _speech?.stop();
    _confetti.dispose();
    super.dispose();
  }

  /// 미리 만든 단계 음성 위치 (#675). 일과 id 가 없으면(저장 전) 기기 음성만
  StoredSpeechSource? _storedSpeechOf(ActionCard card) {
    final routineId = _routine.id;
    if (routineId.isEmpty) return null;
    return (routineId: routineId, stepId: card.id, speechPath: card.speechPath);
  }

  /// 카드를 읽어준다. 읽는 중에 다시 누르면 멈춘다.
  ///
  /// 아동이 여러 번 누를 때 소리가 겹치면 알아들을 수 없다.
  Future<void> _speak(ActionCard card) async {
    final speech = ref.read(speechServiceProvider);

    if (_speakingId == card.id) {
      await speech.stop();
      if (mounted) setState(() => _speakingId = null);
      return;
    }

    setState(() => _speakingId = card.id);

    // 제목만 읽으면 무엇을 해야 하는지가 빠지고, 설명만 읽으면 화면의
    // 큰 제목과 어긋난다. 둘을 이어 붙인다.
    final ok = await speech.speak(
      '${card.displayTitle}. ${card.description}',
      language: _routine.language,
      stored: _storedSpeechOf(card),
    );

    if (!mounted) return;
    setState(() => _speakingId = null);

    // 음성이 없는 언어는 안내창 없이 글만 보여준다
    if (!ok && shouldShowSpeechFailure(_routine.language)) _showFailure();
  }

  /// 소리를 낼 수 없을 때. 식별자는 보호자가 제보할 때 필요하다.
  void _showFailure() {
    showFailure(
      context,
      null,
      title: context.l10n.childDetailSoundFailedTitle,
      fallback: context.l10n.childDetailSoundFailedFallback,
      fallbackCode: 'E-TTS',
    );
  }

  /// 지금 보여줄 일과. 홈이 넘겨준 스냅샷([widget.routine])이 아니라 목록
  /// provider에서 같은 id를 찾아 쓴다 — 서버 동기화 뒤 목록이 갱신되면 카드의
  /// `completed`도 최신이어야 로컬 표시를 걷어냈을 때 서버 값이 맞게 보인다.
  /// 목록에 없으면(로컬 일과 등) 스냅샷으로 둔다.
  Routine _resolveRoutine(List<Routine> routines) => routines.firstWhere(
    (r) => r.id == widget.routine.id,
    orElse: () => widget.routine,
  );

  Routine get _routine => _resolveRoutine(ref.read(childRoutinesProvider));

  /// 목록이 바뀌어도 이룸이가 보던 카드를 계속 보여준다.
  ///
  /// 보던 카드가 새 위치로 옮겨졌으면 그 위치로 따라간다. 카드가 없어졌으면 따라갈 곳이
  /// 없으므로 그 자리를 그대로 두고 지금 보이는 카드를 새 기준으로 삼는다.
  void _followCard(List<ActionCard> cards) {
    if (cards.isEmpty) return;
    final index = _currentIndex.clamp(0, cards.length - 1);
    final anchor = _anchorId;
    if (anchor == null || cards[index].id == anchor) {
      _anchorId = cards[index].id;
      return;
    }
    final moved = cards.indexWhere((card) => card.id == anchor);
    if (moved < 0) {
      _anchorId = cards[index].id;
      return;
    }
    // build 중에 컨트롤러를 움직일 수 없다 — 프레임이 끝난 뒤 옮긴다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpToPage(moved);
    });
  }

  /// [card]가 지금 체크된 상태인지. 기기 기록이 서버 값보다 우선한다.
  bool _isCardChecked(ActionCard card) =>
      ref.read(childRoutineProvider).isChecked(widget.routine.id, card);

  /// 보상(별 화면 → 일과완료 화면) 흐름이 진행 중인가. 도는 동안 다른 카드를 체크해도
  /// 별 화면을 또 쌓지 않는다 — 쌓이면 `좋아요!`를 눌러도 같은 화면이 한 번 더 떠서 안 닫힌 것처럼 보인다.
  bool _rewardFlowActive = false;

  Future<void> _toggle(ActionCard card) async {
    // toggle 전에 현재 상태를 읽어둔다 — 미체크→체크로 "바뀌는" 순간에만
    // 컨페티를 터뜨리기 위해서다. 체크 해제 때는 터지지 않는다.
    final wasChecked = _isCardChecked(card);

    final shouldReward = ref
        .read(childRoutineProvider.notifier)
        .toggle(routine: _routine, card: card);

    // 별 개수가 서버에서 바뀌었다 — 홈 별 배지가 다음 조회에서 갱신되게 한다
    ref.invalidate(memberProvider);

    // 미체크→체크로 바뀐 순간마다 컨페티를 터뜨린다(재체크 포함).
    // 동작 줄이기(Reduce Motion)가 켜져 있으면 색 전환만 남기고 생략한다.
    final becameChecked = !wasChecked;
    if (becameChecked && !MediaQuery.disableAnimationsOf(context)) {
      _confetti.play();
    }

    // 손에도 알린다. 컨페티와 같은 순간에 울리되, 동작 줄이기와는 별개다 — 움직임과 진동은
    // 다른 감각이다. 끄고 켜는 것은 설정의 스위치가 정한다. 기다리지 않는다.
    final haptics = ref.read(childHapticsProvider);
    haptics.play(
      becameChecked ? ChildHapticKind.check : ChildHapticKind.uncheck,
    );

    // 칭찬 소리 (#777): 체크 순간만, 마지막 카드면 일과 완료 칭찬. 카드 읽기와 겹치지 않게 먼저 끊는다
    if (becameChecked) _playPraise();

    if (!shouldReward || _rewardFlowActive) return;
    _rewardFlowActive = true;
    try {
      // 컨페티가 눈에 보인 뒤 보상이 뜨게 한다. 바로 넘어가면 색종이가 안 보인다.
      // 컨페티가 없는 경우(재체크 아님/동작 줄이기)라도 체크 색 전환은 보여야 하므로
      // 최소 전환 시간만큼은 기다린다.
      await Future<void>.delayed(
        becameChecked ? AppMotion.slow + AppMotion.normal : AppMotion.normal,
      );
      if (!mounted) return;
      // 카드를 하나 끝낼 때마다 별을 보여준다. 보호자가 정한 보상도 함께 뜬다.
      // 같은 카드를 다시 체크할 때는 뜨지 않는다 — 위 `shouldReward`가 걸러 준다.
      final routine = widget.routine;
      haptics.play(ChildHapticKind.star);
      await context.push(
        Routes.childReward,
        extra: routine.hasReward
            ? (emoji: routine.rewardEmoji, text: routine.rewardText)
            : null,
      );
      if (!mounted) return;

      // 마지막 카드까지 끝냈으면 일과완료 화면을 이어서 보여 준다.
      // 그 화면의 버튼이 홈으로 보내므로 여기서는 카드를 넘기지 않는다.
      if (_isRoutineDone) {
        haptics.play(ChildHapticKind.complete);
        await context.push(
          Routes.childRoutineDone,
          extra: routine.hasReward
              ? (emoji: routine.rewardEmoji, text: routine.rewardText)
              : null,
        );
        return;
      }
      _advanceToNextUnchecked();
    } finally {
      _rewardFlowActive = false;
    }
  }

  /// 칭찬 소리 재생: 읽기 중단 > 완료 여부로 종류 선택 > 재생 (기다리지 않음)
  void _playPraise() {
    if (_speakingId != null) {
      unawaited(ref.read(speechServiceProvider).stop());
      setState(() => _speakingId = null);
    }
    unawaited(
      ref
          .read(childPraiseSoundProvider)
          .play(
            _isRoutineDone ? ChildPraiseKind.complete : ChildPraiseKind.check,
            language: _routine.language,
          ),
    );
  }

  /// 모든 카드가 체크됐는지. 기기 기록이 서버 값보다 우선한다.
  bool get _isRoutineDone {
    final routine = _routine;
    final progress = ref.read(childRoutineProvider);
    return routine.steps.isNotEmpty &&
        routine.steps.every((card) => progress.isChecked(routine.id, card));
  }

  /// 별 화면을 닫은 뒤 **아직 안 한 카드 중 가장 앞**으로 넘어간다.
  ///
  /// 끝낸 카드가 그대로 남으면 다음 카드를 보려고 옆으로 밀어야 하는데, 미는 동작은
  /// 누르기보다 어렵고 **지금 할 일이 무엇인지** 흐려진다.
  ///
  /// **"다음"을 순서가 아니라 남은 일로 정의한다.** 중간을 건너뛰고 뒤를 체크했을 때
  /// 그저 앞으로만 가면 빠뜨린 카드가 영영 남는다. 남은 것이 없으면 움직이지 않는다 —
  /// 일과를 다 끝낸 경우는 호출 전에 일과완료 화면이 가져간다.
  ///
  /// 체크 해제와 재체크 때는 이 함수까지 오지 않는다. 별 화면이 뜨지 않기 때문인데,
  /// 연출 없이 화면만 바뀌면 이룸이가 무엇이 일어났는지 알 수 없다.
  void _advanceToNextUnchecked() {
    if (!_controller.hasClients) return;
    final routine = _routine;
    final progress = ref.read(childRoutineProvider);
    final next = routine.steps.indexWhere(
      (card) => !progress.isChecked(routine.id, card),
    );
    if (next < 0 || next == _currentIndex) return;
    _goToPage(next);
  }

  /// [index] 카드로 넘어간다. 별 화면 뒤 다음 카드로, 옆 카드를 눌렀을 때 쓴다.
  void _goToPage(int index) {
    if (!_controller.hasClients) return;
    // 갑자기 바뀌면 무엇이 일어났는지 모른다. 아동 화면은 300ms 이상으로 둔다.
    // 동작 줄이기가 켜져 있으면 애니메이션만 생략하고 이동은 그대로 한다.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
      return;
    }
    _controller.animateToPage(
      index,
      duration: AppMotion.normal,
      curve: AppMotion.standard,
    );
  }

  /// 지금 카드의 체크 버튼 (폰: 카드 아래 / 태블릿: 카드 안, [sizeScale] 만큼 크게)
  Widget _buildCheckButton(
    List<ActionCard> cards,
    bool Function(String routineId, ActionCard card) isChecked,
    String routineId, {
    double sizeScale = 1.0,
  }) {
    return Builder(
      builder: (context) {
        final current = cards[_currentIndex.clamp(0, cards.length - 1)];
        return ChildRoutineCheckButton(
          isChecked: isChecked(routineId, current),
          confettiController: _confetti,
          onTap: () => _toggle(current),
          sizeScale: sizeScale,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 보던 일과가 사라졌다 — 그 일과를 만든 보호자가 이룸이에서 나갔다 (다중 보호자 · E11).
    // 오류 화면을 띄우지 않고 홈으로 돌아간다. 홈은 같은 때 목록을 다시 받는다.
    ref.listen<bool>(
      childRoutineProvider.select((s) => s.gone.contains(widget.routine.id)),
      (_, gone) {
        if (gone) context.go(Routes.child);
      },
    );

    final routine = _resolveRoutine(ref.watch(childRoutinesProvider));
    final cards = routine.steps;
    _followCard(cards);
    final progress = ref.watch(childRoutineProvider);

    final topBar = ChildRoutineDetailTopBar(
      onBack: context.popOrHome,
      title: routine.displayTitle,
      language: routine.language,
    );

    // 카드 넘기기 상자. 가운데 카드는 시안 자리(333 @ x=30) 그대로, 옆 카드는 가장자리에
    // 20 걸친다 (시안 이탈 — 시안도 옆 카드를 x373에 둔다). 카드는 이 자리 높이를 채운다.
    final pager = ChildCardPager(
      controller: _controller,
      cards: cards,
      routineId: routine.id,
      language: routine.language,
      currentIndex: cards.isEmpty
          ? 0
          : _currentIndex.clamp(0, cards.length - 1),
      speakingId: _speakingId,
      onSpeak: _speak,
      // 카드를 넘기면 체크 버튼 대상도 바뀐다
      onPageChanged: (index) {
        // 넘길 때마다 가볍게 — 옆 카드를 눌러 넘어갈 때도 같다
        playChildHaptic(context, ChildHapticKind.select);
        setState(() {
          // 이룸이가 직접 넘긴 것이므로 새 카드를 기준으로 삼는다
          if (index >= 0 && index < cards.length) {
            _anchorId = cards[index].id;
          }
        });
      },
      onSideTap: _goToPage,
      // 옆에 걸친 카드에도 한 것을 표시한다
      isChecked: (card) => progress.isChecked(routine.id, card),
    );

    final checkButton = _buildCheckButton(
      cards,
      progress.isChecked,
      routine.id,
    );

    // 🔴 하는 동안 보상이 계속 보인다 (수행 중 보상 노출이 핵심 기능).
    // 완료 후에만 뜨는 별 연출과 다른 기능이다 — 끝까지 가는 힘이 여기서 나온다.
    final rewardBanner = RewardBanner.maybe(routine);

    // 태블릿: 순서 줄 + 꽉 찬 카드 한 장, 체크 버튼은 카드 안 (#789). 폰은 아래 시안 배치 그대로
    if (context.layoutMetrics.isScaleOverridden) {
      final currentIndex = cards.isEmpty
          ? 0
          : _currentIndex.clamp(0, cards.length - 1);
      return ChildRoutineDetailTabletBody(
        topBar: topBar,
        routine: routine,
        currentIndex: currentIndex,
        isChecked: (card) => progress.isChecked(routine.id, card),
        onStepTap: _goToPage,
        pager: ChildTabletCardPager(
          controller: _controller,
          cards: cards,
          routineId: routine.id,
          language: routine.language,
          currentIndex: currentIndex,
          speakingId: _speakingId,
          onSpeak: _speak,
          onPageChanged: pager.onPageChanged,
          checkButton: _buildCheckButton(
            cards,
            progress.isChecked,
            routine.id,
            sizeScale: _tabletCheckScale,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: ChildRoutineDetailScreen._backTop.h),
            topBar,
            SizedBox(height: ChildRoutineDetailScreen._topBarToReward.h),
            // **보상이 없어도 칩 자리는 비워 둔다.** 시안은 칩·카드·버튼이 모두 고정
            // 자리라, 자리를 걷으면 일과마다 카드가 오르내려 보인다.
            SizedBox(height: RewardBanner.height.h, child: rewardBanner),
            SizedBox(height: ChildRoutineDetailScreen._rewardToCard.h),
            // **카드 자리를 시안 높이로 못 박는다.**
            //
            // `Expanded`로 남는 높이를 카드에 다 주면 그 아래 체크 버튼이 화면
            // 바닥까지 밀려 시안보다 내려간다. 시안은 카드도 버튼도
            // 자리가 고정이다 — 카드 y=231 (333×410), 버튼 y=675 (88×88).
            //
            // `Flexible`로 감싸 두면 화면이 짧을 때 이 상자가 먼저 줄어들어
            // 버튼이 잘려 나가지 않는다.
            Flexible(
              child: SizedBox(
                height: ChildRoutineDetailScreen._cardBoxHeight.h,
                child: pager,
              ),
            ),
            // 시안 카드 아래(641) → 체크 버튼(675) 사이 34
            SizedBox(height: ChildRoutineDetailScreen._cardToCheck.h),
            checkButton,
          ],
        ),
      ),
    );
  }
}

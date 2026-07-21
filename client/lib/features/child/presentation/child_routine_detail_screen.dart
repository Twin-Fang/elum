import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';
import '../../guardian/data/routine_repository.dart';
import '../../guardian/presentation/widgets/action_card_view.dart';
import '../application/child_routine_notifier.dart';
import '../data/speech_service.dart';

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

  @override
  ConsumerState<ChildRoutineDetailScreen> createState() =>
      _ChildRoutineDetailScreenState();
}

class _ChildRoutineDetailScreenState
    extends ConsumerState<ChildRoutineDetailScreen> {
  final _controller = PageController(viewportFraction: 0.88);

  /// 체크 순간 색종이가 터진다. `play()`가 이 duration만큼 색종이를 뿜는다.
  /// 아동 화면 최소 전환 시간(300ms) 이상으로 둔다.
  final _confetti = ConfettiController(duration: AppMotion.normal);

  /// 지금 읽고 있는 카드 id. null이면 아무것도 안 읽고 있다.
  String? _speakingId;

  /// dispose에서 `ref`를 읽으면 "unmounted" 오류가 난다.
  /// 미리 잡아두고 정리할 때 쓴다.
  SpeechService? _speech;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 뒤에 잡는다. initState에서 읽어도 되지만 일관되게 둔다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speech = ref.read(speechServiceProvider);
    });
  }

  @override
  void dispose() {
    // 화면을 벗어나도 소리가 남으면 다음 화면까지 따라온다
    _speech?.stop();
    _confetti.dispose();
    _controller.dispose();
    super.dispose();
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
    final ok = await speech.speak('${card.displayTitle}. ${card.description}');

    if (!mounted) return;
    setState(() => _speakingId = null);

    if (!ok) _showFailure();
  }

  /// 소리를 낼 수 없을 때. 아동은 못 읽지만 보호자가 제보할 때 필요하다.
  void _showFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('소리를 재생할 수 없어요 (E-TTS)')),
    );
  }

  /// 현재 보고 있는 카드. 체크 버튼이 이 카드를 대상으로 한다.
  int get _currentIndex =>
      _controller.hasClients ? (_controller.page ?? 0).round() : 0;

  /// [card]가 지금 체크된 상태인지. 로컬 진행 상태나 서버 값 어느 쪽이든 체크로 본다.
  bool _isCardChecked(ActionCard card) =>
      ref.read(childRoutineProvider).isCompleted(card.id) || card.completed;

  Future<void> _toggle(ActionCard card) async {
    // toggle 전에 현재 상태를 읽어둔다 — 미체크→체크로 "바뀌는" 순간에만
    // 컨페티를 터뜨리기 위해서다. 체크 해제 때는 터지지 않는다.
    final wasChecked = _isCardChecked(card);

    final shouldReward = ref
        .read(childRoutineProvider.notifier)
        .toggle(routineId: widget.routine.id, cardId: card.id);

    // 별 개수가 서버에서 바뀌었다 — 홈 별 배지가 다음 조회에서 갱신되게 한다
    ref.invalidate(memberProvider);

    // 미체크→체크로 바뀐 순간마다 컨페티를 터뜨린다(재체크 포함).
    // 동작 줄이기(Reduce Motion)가 켜져 있으면 색 전환만 남기고 생략한다.
    final becameChecked = !wasChecked;
    if (becameChecked && !MediaQuery.disableAnimationsOf(context)) {
      _confetti.play();
    }

    if (!shouldReward) return;

    // 컨페티가 눈에 보인 뒤 보상이 뜨게 한다. 바로 넘어가면 색종이가 안 보인다.
    // 컨페티가 없는 경우(재체크 아님/동작 줄이기)라도 체크 색 전환은 보여야 하므로
    // 최소 전환 시간만큼은 기다린다.
    await Future<void>.delayed(
      becameChecked ? AppMotion.slow + AppMotion.normal : AppMotion.normal,
    );
    if (mounted) context.push(Routes.childReward);
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.routine.steps;
    final progress = ref.watch(childRoutineProvider);
    final space = context.space;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onBack: () => context.pop(),
              title: widget.routine.displayTitle,
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: cards.length,
                // 카드를 넘기면 체크 버튼 대상도 바뀐다
                onPageChanged: (_) => setState(() {}),
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: space.xs,
                    vertical: space.md,
                  ),
                  child: ActionCardView(
                    key: ValueKey(cards[index].id),
                    card: cards[index],
                    index: index,
                    routineId: widget.routine.id,
                    onSpeak: () => _speak(cards[index]),
                    isSpeaking: _speakingId == cards[index].id,
                  ),
                ),
              ),
            ),
            SizedBox(height: space.lg),
            Builder(builder: (context) {
              final current = cards[_currentIndex.clamp(0, cards.length - 1)];
              return _CheckButton(
                isChecked: progress.isCompleted(current.id) || current.completed,
                confettiController: _confetti,
                onTap: () => _toggle(current),
              );
            }),
            SizedBox(height: space.xl),
          ],
        ),
      ),
    );
  }
}

/// 뒤로가기 + 일과 제목 (Figma 309:3548 상단, 2026-07-22 시안).
///
/// 캐릭터 배지가 빠지고 어떤 일과의 카드인지 제목이 중앙에 뜬다.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.title});

  final VoidCallback onBack;

  /// 일과 제목 (`Routine.displayTitle`). 비어도 대체어가 온다.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.space.screenH,
        context.space.md,
        context.space.screenH,
        0,
      ),
      child: Row(
        children: [
          AppPressable(
            onTap: onBack,
            scaleDown: AppPressable.scaleIcon,
            // 아동 모드 터치 타겟을 넉넉히 잡는다
            child: SizedBox(
              width: 64.w,
              height: 64.w,
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.iconBack,
                  width: 28.w,
                  height: 28.w,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typo.childDetailTitle
                  .copyWith(color: context.colors.textPrimary),
            ),
          ),
          // 뒤로가기와 같은 폭을 비워 제목이 정확히 가운데 온다
          SizedBox(width: 64.w),
        ],
      ),
    );
  }
}

/// 88×88 체크 버튼 + 체크 순간 터지는 컨페티.
///
/// 체크 전에는 테두리만, 체크 후에는 채워진다.
/// 부모가 [confettiController]로 `play()`를 호출하면 버튼 중심에서 색종이가
/// 사방으로 터진다 — 발동 조건(미체크→체크·동작 줄이기 존중)은 부모가 판단한다.
class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.isChecked,
    required this.confettiController,
    required this.onTap,
  });

  final bool isChecked;
  final ConfettiController confettiController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = ChildRoutineDetailScreen.checkButtonSize.w
        .clamp(ChildRoutineDetailScreen.minTouchTarget, double.infinity);

    // 색종이가 버튼 중심에서 사방으로 뿜어져 나오도록 겹쳐 놓는다.
    // ConfettiWidget은 자식(버튼)이 놓인 지점을 방출 원점으로 삼는다.
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        ConfettiWidget(
          confettiController: confettiController,
          // 한 방향이 아니라 원점에서 사방으로 터지는 '폭죽' 형태
          blastDirectionality: BlastDirectionality.explosive,
          // 아동 화면이라 과하지 않게. 짧게 팍 터지고 사라진다.
          emissionFrequency: 0,
          numberOfParticles: 18,
          maxBlastForce: 18,
          minBlastForce: 8,
          gravity: 0.25,
          shouldLoop: false,
          colors: colors.confetti,
        ),
        AppPressable(
          onTap: onTap,
          scaleDown: AppPressable.scaleButton,
          child: AnimatedContainer(
            // 아동 화면은 300ms 이상으로 둔다 (docs/motion.md)
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            // 원형 버튼이라 가로세로 모두 .w. 좁은 기기에서 줄어들어도
            // 아동 모드 최소 터치 타겟(64) 아래로는 내려가지 않게 막는다.
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isChecked ? colors.checkDone : Colors.transparent,
              // 완료되면 채움만 남긴다 — 회색 테두리가 남으면 덜 끝난 느낌을 준다
              // (Figma 309:3682)
              border: isChecked
                  ? null
                  : Border.all(color: colors.checkPending, width: 8.w),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 44.w,
              color: isChecked ? colors.surface : colors.checkPending,
            ),
          ),
        ),
      ],
    );
  }
}

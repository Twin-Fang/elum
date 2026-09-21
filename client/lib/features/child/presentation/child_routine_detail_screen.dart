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
import 'widgets/reward_banner.dart';
import '../../guardian/data/routine_repository.dart';
import '../../guardian/presentation/widgets/action_card_view.dart';
import '../application/child_routine_notifier.dart';
import '../data/speech_service.dart';
import 'child_home_screen.dart' show childRoutinesProvider;

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

  /// 상단바 아래에서 카드 윗변까지 (시안 `309:3548` — 카드 y=180).
  static const _cardTopGap = 41.0;

  /// 카드 자리 높이 (시안 345×431). 카드가 이보다 짧아도 이 자리는 유지한다.
  static const _cardBoxHeight = 431.0;

  /// 카드 자리 아래(611)에서 체크 버튼(675)까지.
  static const _cardToCheck = 64.0;

  /// 체크 버튼. 화면에 누를 것이 여럿이라 테스트가 타입만으로는 갈라내지 못한다.
  static const checkButtonKey = ValueKey('child.routine.check');

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('소리를 재생할 수 없어요 (E-TTS)')));
  }

  /// 현재 보고 있는 카드. 체크 버튼이 이 카드를 대상으로 한다.
  int get _currentIndex =>
      _controller.hasClients ? (_controller.page ?? 0).round() : 0;

  /// 지금 보여줄 일과. 홈이 넘겨준 스냅샷([widget.routine])이 아니라 목록
  /// provider에서 같은 id를 찾아 쓴다 — 서버 동기화 뒤 목록이 갱신되면 카드의
  /// `completed`도 최신이어야 로컬 표시를 걷어냈을 때 서버 값이 맞게 보인다.
  /// 목록에 없으면(로컬 일과 등) 스냅샷으로 둔다.
  Routine _resolveRoutine(List<Routine> routines) => routines.firstWhere(
    (r) => r.id == widget.routine.id,
    orElse: () => widget.routine,
  );

  Routine get _routine => _resolveRoutine(ref.read(childRoutinesProvider));

  /// [card]가 지금 체크된 상태인지. 기기 기록이 서버 값보다 우선한다.
  bool _isCardChecked(ActionCard card) =>
      ref.read(childRoutineProvider).isChecked(widget.routine.id, card);

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

    if (!shouldReward) return;

    // 컨페티가 눈에 보인 뒤 보상이 뜨게 한다. 바로 넘어가면 색종이가 안 보인다.
    // 컨페티가 없는 경우(재체크 아님/동작 줄이기)라도 체크 색 전환은 보여야 하므로
    // 최소 전환 시간만큼은 기다린다.
    await Future<void>.delayed(
      becameChecked ? AppMotion.slow + AppMotion.normal : AppMotion.normal,
    );
    if (!mounted) return;
    // 카드를 하나 끝낼 때마다 별을 보여준다. 보호자가 정한 보상도 함께 뜬다 (이슈 #239).
    // 같은 카드를 다시 체크할 때는 뜨지 않는다 — 위 `shouldReward`가 걸러 준다.
    final routine = widget.routine;
    await context.push(
      Routes.childReward,
      extra: routine.hasReward
          ? (emoji: routine.rewardEmoji, text: routine.rewardText)
          : null,
    );
    if (!mounted) return;
    _advanceToNextUnchecked();
  }

  /// 별 화면을 닫은 뒤 **아직 안 한 카드 중 가장 앞**으로 넘어간다 (이슈 #293).
  ///
  /// 전에는 별 화면을 닫으면 방금 끝낸 카드가 그대로 남아, 다음 카드를 보려면
  /// 화면을 옆으로 밀어야 했다. 미는 동작은 누르기보다 어렵고, 끝낸 카드가 계속
  /// 떠 있으면 **지금 할 일이 무엇인지** 흐려진다.
  ///
  /// **"다음"을 순서가 아니라 남은 일로 정의한다.** 중간을 건너뛰고 뒤를 체크했을 때
  /// 그저 앞으로만 가면 빠뜨린 카드가 영영 남는다. 남은 것이 없으면 움직이지 않는다 —
  /// 일과를 다 끝냈을 때 보여줄 화면은 시안이 나온 뒤 따로 만든다.
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

    // 갑자기 바뀌면 무엇이 일어났는지 모른다. 아동 화면은 300ms 이상으로 둔다.
    // 동작 줄이기가 켜져 있으면 애니메이션만 생략하고 이동은 그대로 한다.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(next);
      return;
    }
    _controller.animateToPage(
      next,
      duration: AppMotion.normal,
      curve: AppMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final routine = _resolveRoutine(ref.watch(childRoutinesProvider));
    final cards = routine.steps;
    final progress = ref.watch(childRoutineProvider);
    final space = context.space;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => context.pop(), title: routine.displayTitle),
            // 🔴 하는 동안 보상이 계속 보인다 (이슈 #239 · 2026-09-13 자문 핵심).
            // 완료 후에만 뜨는 별 연출과 다른 기능이다 — 끝까지 가는 힘이 여기서 나온다.
            // 보상이 없으면 자리도 없다.
            if (routine.hasReward) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  space.screenH,
                  space.xs,
                  space.screenH,
                  0,
                ),
                child: RewardBanner.maybe(routine, compact: true),
              ),
            ],
            // 상단바 아래(139)에서 시안 카드 윗변(y=180)까지 41.
            // 토큰(16)을 쓰면 카드가 25 올라간다.
            SizedBox(height: ChildRoutineDetailScreen._cardTopGap.h),
            // **카드 자리를 시안 높이로 못 박는다.**
            //
            // `Expanded`로 남는 높이를 카드에 다 주면 그 아래 체크 버튼이 화면
            // 바닥까지 밀려 **시안보다 36 내려간다** (#297). 시안은 카드도 버튼도
            // 자리가 고정이다 — 카드 y=180 (345×431), 버튼 y=675 (88×88).
            //
            // `Flexible`로 감싸 두면 화면이 짧을 때 이 상자가 먼저 줄어들어
            // 버튼이 잘려 나가지 않는다.
            Flexible(
              child: SizedBox(
                height: ChildRoutineDetailScreen._cardBoxHeight.h,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: cards.length,
                  // 카드를 넘기면 체크 버튼 대상도 바뀐다
                  onPageChanged: (_) => setState(() {}),
                  // **좌우 여백을 주지 않는다.** `viewportFraction`(0.88)이 이미
                  // 항목을 345.8 폭으로 잘라 시안 카드(345 @ x=24)와 같다.
                  //
                  // **위에서부터 쌓는다.** 가운데로 두면 카드가 내려간다.
                  itemBuilder: (context, index) => Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // **`Flexible`이다.** 그냥 두면 내용이 길 때 카드가
                      // 무한히 커져 오버플로한다(실제로 590 넘쳤다). 남는
                      // 높이를 상한으로 주면, 넘치는 카드는 안쪽 스크롤이 받는다.
                      Flexible(
                        child: ActionCardView(
                          key: ValueKey(cards[index].id),
                          card: cards[index],
                          index: index,
                          routineId: routine.id,
                          onSpeak: () => _speak(cards[index]),
                          isSpeaking: _speakingId == cards[index].id,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 시안 카드 아래(611) → 체크 버튼(675) 사이 64
            SizedBox(height: ChildRoutineDetailScreen._cardToCheck.h),
            Builder(
              builder: (context) {
                final current = cards[_currentIndex.clamp(0, cards.length - 1)];
                return _CheckButton(
                  isChecked: progress.isChecked(routine.id, current),
                  confettiController: _confetti,
                  onTap: () => _toggle(current),
                );
              },
            ),
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
      // **위에서부터 쌓는다.** 가운데 정렬로 두면 제목이 64 상자의 한가운데로
      // 가 시안보다 8 내려간다 (#297).
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPressable(
            onTap: onBack,
            scaleDown: AppPressable.scaleIcon,
            // 아동 모드 터치 타겟을 넉넉히 잡는다
            child: SizedBox(
              width: 64.w,
              height: 64.w,
              // **누를 자리와 그림 자리를 따로 둔다.** 64 상자 한가운데에
              // 그리면 시안(`356:5169` — 24×24 @ 24,87)보다 12 오른쪽·6 아래로
              // 밀리고 크기도 28이라 넷 크다 (#297). 상자 왼위 모서리에 붙이고
              // 위로만 12 띄우면 그림이 시안 자리에 온다 — 좌우 여백
              // (`screenH` 24)이 이미 시안 x와 같다. 누를 자리는 64 그대로다.
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: SvgPicture.asset(
                    AppAssets.iconBack,
                    width: 24.w,
                    height: 24.w,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            // 시안 제목은 y=90 — 상단바 시작(75)에서 15 아래다.
            child: Padding(
              padding: EdgeInsets.only(top: 15.h),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.childDetailTitle.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
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
    final size = ChildRoutineDetailScreen.checkButtonSize.w.clamp(
      ChildRoutineDetailScreen.minTouchTarget,
      double.infinity,
    );

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
          key: ChildRoutineDetailScreen.checkButtonKey,
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
              // 채워진 뒤에만 그림자가 붙는다 (시안 `309:3682` — 0 2 5 · 5%).
              // 카드가 쓰는 것과 같은 그림자다.
              boxShadow: isChecked
                  ? [
                      BoxShadow(
                        color: colors.glassShadow,
                        blurRadius: 5.w,
                        offset: Offset(0, 2.h),
                      ),
                    ]
                  : null,
            ),
            // **`Icons.check_rounded`가 아니다.** 그건 획이 가늘어 시안과 나란히
            // 놓으면 진한 픽셀이 607 대 212로 벌어진다. 시안(`993:4331`)은
            // 48×35.76이고 88 상자 한가운데에 온다 (#297).
            child: Center(
              child: SvgPicture.asset(
                AppAssets.childCheckMark,
                width: 48.w,
                height: 35.76.w,
                colorFilter: ColorFilter.mode(
                  isChecked ? colors.surface : colors.checkPending,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

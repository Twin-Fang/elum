import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../guardian/application/routine_notifier.dart';
import '../../guardian/presentation/widgets/action_card_view.dart';
import '../application/child_routine_notifier.dart';
import 'mode_switch_screen.dart';

/// Figma `아이_홈`(309:3548 체크 전 / 309:3648 체크 후).
///
/// 두 프레임은 별도 화면이 아니라 **같은 화면의 체크 상태**다.
///
/// 아동이 직접 조작하므로 터치 타겟이 크고(88×88) 전환이 느리다.
/// 카드를 체크하면 보상 화면이 뜬다 — 단, 같은 카드를 다시 체크할 때는 뜨지 않는다.
class ChildHomeScreen extends ConsumerStatefulWidget {
  const ChildHomeScreen({super.key});

  /// 체크 버튼 크기. 아동 모드 최소 64×64를 넉넉히 넘긴다.
  static const checkButtonSize = 88.0;

  @override
  ConsumerState<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends ConsumerState<ChildHomeScreen> {
  final _controller = PageController(viewportFraction: 0.88);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 현재 보고 있는 카드. 체크 버튼이 이 카드를 대상으로 한다.
  int get _currentIndex =>
      _controller.hasClients ? (_controller.page ?? 0).round() : 0;

  Future<void> _toggle(String cardId) async {
    final shouldReward =
        ref.read(childRoutineProvider.notifier).toggle(cardId);

    if (!shouldReward) return;

    // 체크가 눈에 보인 뒤 보상이 뜨게 한다. 동시에 일어나면 뭘 눌렀는지 모른다.
    await Future<void>.delayed(AppMotion.normal);
    if (mounted) context.push(Routes.childReward);
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(routineFlowProvider).routine?.steps ?? const [];
    final progress = ref.watch(childRoutineProvider);
    final space = context.space;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            if (cards.isEmpty)
              const Expanded(child: _NoRoutine())
            else ...[
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
                    child: ActionCardView(card: cards[index], index: index),
                  ),
                ),
              ),
              SizedBox(height: space.lg),
              _CheckButton(
                isChecked: progress.isCompleted(
                  cards[_currentIndex.clamp(0, cards.length - 1)].id,
                ),
                onTap: () => _toggle(
                  cards[_currentIndex.clamp(0, cards.length - 1)].id,
                ),
              ),
              SizedBox(height: space.xl),
            ],
          ],
        ),
      ),
    );
  }
}

/// 로고 + 캐릭터 배지 (Figma y=70~113)
class _TopBar extends StatelessWidget {
  const _TopBar();

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SvgPicture.asset(AppAssets.homeLogo, width: 80, height: 30),
          // 보호자로 돌아가려면 암호가 필요하다
          AppPressable(
            onTap: () => context.push(
              '${Routes.modeSwitch}?to=${ModeSwitchTarget.guardian.name}',
            ),
            scaleDown: AppPressable.scaleIcon,
            child: SvgPicture.asset(
              AppAssets.characterBadgeRuru,
              width: 56,
              height: 56,
            ),
          ),
        ],
      ),
    );
  }
}

/// 88×88 체크 버튼.
///
/// 체크 전에는 테두리만, 체크 후에는 채워진다.
class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.isChecked, required this.onTap});

  final bool isChecked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleButton,
      child: AnimatedContainer(
        // 아동 화면은 300ms 이상으로 둔다 (docs/motion.md)
        duration: AppMotion.normal,
        curve: AppMotion.standard,
        width: ChildHomeScreen.checkButtonSize,
        height: ChildHomeScreen.checkButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isChecked ? colors.checkDone : Colors.transparent,
          border: Border.all(color: colors.checkPending, width: 8),
        ),
        child: Icon(
          Icons.check_rounded,
          size: 44,
          color: isChecked ? colors.surface : colors.checkPending,
        ),
      ),
    );
  }
}

/// 보호자가 아직 일과를 만들지 않았다.
class _NoRoutine extends StatelessWidget {
  const _NoRoutine();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '오늘의 할 일이 없어요',
        style: context.typo.cardHeadline
            .copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

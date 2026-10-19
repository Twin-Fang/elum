import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'child_routine_detail_screen.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';

/// 88×88 체크 버튼 + 체크 순간 터지는 컨페티.
///
/// 체크 전에는 테두리만, 체크 후에는 채워진다.
/// 부모가 [confettiController]로 `play()`를 호출하면 버튼 중심에서 색종이가
/// 사방으로 터진다 — 발동 조건(미체크→체크·동작 줄이기 존중)은 부모가 판단한다.
class ChildRoutineCheckButton extends StatelessWidget {
  const ChildRoutineCheckButton({
    super.key,
    required this.isChecked,
    required this.confettiController,
    required this.onTap,
    this.sizeScale = 1.0,
  });

  /// 기본 크기(88) 대비 배율. 태블릿 카드 안에서 키운다 (폰은 1)
  final double sizeScale;

  final bool isChecked;
  final ConfettiController confettiController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size =
        ChildRoutineDetailScreen.checkButtonSize.w.clamp(
          ChildRoutineDetailScreen.minTouchTarget,
          double.infinity,
        ) *
        sizeScale;

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
        // 그림(체크 표시)뿐인 버튼이라 이름을 준다. 누를 때마다 켜고 끄므로
        // 이름만으로는 이미 했는지 모른다 — 켜짐 상태(checked)도 함께 알린다.
        // AppPressable 의 이름 자리는 상태를 못 담아 여기서 직접 감싼다.
        Semantics(
          container: true,
          button: true,
          checked: isChecked,
          label: context.l10n.childDetailCheckLabel,
          child: AppPressable(
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
                    : Border.all(
                        color: colors.checkPending,
                        width: 8.w * sizeScale,
                      ),
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
              // 48×35.76이고 88 상자 한가운데에 온다.
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.childCheckMark,
                  width: 48.w * sizeScale,
                  height: 35.76.w * sizeScale,
                  colorFilter: ColorFilter.mode(
                    isChecked ? colors.surface : colors.checkPending,
                    BlendMode.srcIn,
                  ),
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

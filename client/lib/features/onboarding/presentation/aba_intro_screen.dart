import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_fade_slide_in.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_scaffold.dart';
import 'widgets/aba_intro_parts.dart';

/// 이룸 설계 원리(ABA) 소개: 루미 그림 > 제목 > 원리 칸 2x2 > 보호자 상자 (소개 사이트 ABA 4가지와 같은 그림·말)
/// 들어오는 곳 2개: 온보딩(역할 선택 > 이 화면 > 이름 입력, `시작하기`) · 설정 다시 보기(제목 줄 + 뒤로가기만)
class AbaIntroScreen extends StatelessWidget {
  const AbaIntroScreen({super.key, required this.isFromSettings});

  /// 설정 > `이룸은 이렇게 만들었어요` 에서 열었는가 (제목 줄 있음, 주 버튼 없음)
  final bool isFromSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    // 등장 순서: 머리 0 > 칸 1~4 > 보호자 상자 5
    Widget appear(int order, Widget child) =>
        AppFadeSlideIn(delay: AppMotion.sceneStagger * order, duration: AppMotion.slow, curve: AppMotion.decelerate, child: child);
    final principles = [
      AbaPrincipleTile(asset: AppAssets.abaTileSteps, title: l10n.abaIntroStepsTitle, body: l10n.abaIntroStepsBody),
      AbaPrincipleTile(asset: AppAssets.abaTileShow, title: l10n.abaIntroShowTitle, body: l10n.abaIntroShowBody),
      AbaPrincipleTile(asset: AppAssets.abaTileHelp, title: l10n.abaIntroHelpTitle, body: l10n.abaIntroHelpBody),
      AbaPrincipleTile(asset: AppAssets.abaTileReward, title: l10n.abaIntroRewardTitle, body: l10n.abaIntroRewardBody),
    ];
    return ElumScaffold(
      // 온보딩은 역할 선택에서 push 로 들어와 돌아갈 곳이 있음
      onBack: context.popOrHome,
      title: isFromSettings ? l10n.guardianSettingsAboutElum : null,
      backTop: isFromSettings ? ElumScaffold.settingsBackTop : null,
      horizontalPadding: space.md,
      bottomButton: isFromSettings
          ? null
          : ElumButton(label: l10n.abaIntroStart, onPressed: () => context.push(Routes.onboardingName)),
      // 보통 글자 폰은 한 화면, 큰 글자·작은 화면은 스크롤 (남는 높이는 위아래로 나눠 가운데)
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                appear(0, const AbaIntroHero()),
                SizedBox(height: space.md.h),
                AbaPrincipleGrid(tiles: [for (final (index, tile) in principles.indexed) appear(index + 1, tile)]),
                SizedBox(height: space.md.h),
                appear(principles.length + 1, const AbaGuardianNote()),
                SizedBox(height: space.xs.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

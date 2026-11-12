import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../../../core/widgets/elum_row_card.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/kept_text.dart';

/// 이룸 설계 원리(ABA) 소개: 그림 > 제목 > 원리 3줄 > 보호자 묶음 (#1277)
/// 들어오는 곳 2개: 온보딩(역할 선택 > 이 화면 > 이름 입력, `시작하기`) · 설정 다시 보기(뒤로가기만)
class AbaIntroScreen extends StatelessWidget {
  const AbaIntroScreen({super.key, required this.isFromSettings});

  /// 설정 > `이룸은 이렇게 만들었어요` 에서 열었는가 (제목 줄 있음, 주 버튼 없음)
  final bool isFromSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    return ElumScaffold(
      // 온보딩은 역할 선택에서 push 로 들어와 돌아갈 곳이 있음
      onBack: context.popOrHome,
      title: isFromSettings ? l10n.guardianSettingsAboutElum : null,
      backTop: isFromSettings ? ElumScaffold.settingsBackTop : null,
      bottomButton: isFromSettings
          ? null
          : ElumButton(label: l10n.abaIntroStart, onPressed: () => context.push(Routes.onboardingName)),
      // 큰 글자에서 길어지면 스크롤
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: space.lg.h),
        child: ElumGuidePanel(
          placement: ElumGuidePlacement.sheet,
          illustration: const ElumGuideIllustration(
            asset: AppAssets.abaIntroLumi,
            size: ElumGuideIllustrationSize.sheet,
          ),
          title: l10n.abaIntroTitle,
          description: l10n.abaIntroSubtitle,
          content: [
            // 원리 3줄 (카드 > 소리 > 별)
            ElumGuideFeatureRow(
              iconAsset: AppAssets.iconPlayingCards,
              title: l10n.abaIntroCardTitle,
              description: l10n.abaIntroCardBody,
            ),
            ElumGuideFeatureRow(
              iconAsset: AppAssets.iconVolume,
              title: l10n.abaIntroVoiceTitle,
              description: l10n.abaIntroVoiceBody,
            ),
            ElumGuideFeatureRow(
              iconAsset: AppAssets.iconStar,
              title: l10n.abaIntroStarTitle,
              description: l10n.abaIntroStarBody,
            ),
            SizedBox(height: space.md.h),
            const _GuardianFirstNote(),
          ],
        ),
      ),
    );
  }
}

/// 보호자 묶음: 줄 카드 판 위 제목 + 설명 (원리보다 보호자가 중심이라는 마무리)
class _GuardianFirstNote extends StatelessWidget {
  const _GuardianFirstNote();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final bodyStyle = context.typo.creditBody;
    return ElumRowCardFrame(
      minHeight: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: space.xs.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KeptText(
              l10n.abaIntroGuardianTitle,
              style: bodyStyle.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: (space.xs / 2).h),
            KeptText(l10n.abaIntroGuardianBody, style: bodyStyle.copyWith(color: colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

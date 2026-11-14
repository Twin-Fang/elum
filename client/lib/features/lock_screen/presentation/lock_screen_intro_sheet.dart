import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../../../core/widgets/elum_secondary_button.dart';

/// 잠금화면 소개 시트 고른 것: 켜러 가기 · 미리 보기 · 나중에(닫기)
enum LockScreenIntroChoice { turnOn, preview }

/// 잠금화면 소개 시트 (이룸이 첫 완료 뒤 1회 + 7일 뒤 1회): 3D 그림 > 제목 > 한 줄 > 켜 보기 > 미리 보기 · 나중에
class LockScreenIntroSheet extends StatelessWidget {
  const LockScreenIntroSheet({super.key});

  @override
  Widget build(BuildContext context) => ElumGuidePanel(
    placement: ElumGuidePlacement.sheet,
    illustration: const ElumGuideIllustration(
      asset: AppAssets.featureIconLockScreen,
      size: ElumGuideIllustrationSize.sheet,
    ),
    title: context.l10n.lockScreenIntroTitle,
    description: context.l10n.lockScreenIntroBody,
    content: [ElumGuideNote(text: context.l10n.lockScreenIntroNoAdsNote)],
    primaryAction: ElumGuideAction(
      label: context.l10n.lockScreenIntroTurnOn,
      onTap: () => Navigator.of(context).pop(LockScreenIntroChoice.turnOn),
    ),
    secondaryActions: [
      ElumSecondaryButton(
        label: context.l10n.lockScreenPreviewAction,
        onTap: () => Navigator.of(context).pop(LockScreenIntroChoice.preview),
      ),
      ElumSecondaryButton(
        label: context.l10n.lockScreenIntroLater,
        onTap: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

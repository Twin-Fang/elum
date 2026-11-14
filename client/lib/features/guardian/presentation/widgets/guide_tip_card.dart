import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_info_card.dart';
import '../../../../core/widgets/home_notice_card.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/utils/open_notice_link.dart';
import '../../application/guide_tip_controller.dart';
import '../../domain/guide_tip.dart';

/// 안내 글을 열지 못했을 때 실패 팝업 코드
const guideTipOpenFailedCode = 'E-GUIDE-LINK';

/// 보호자 화면 가이드 팁 자리: 자리별 안 닫은 첫 팁 하나 > ElumInfoCard (3D 그림 + 제목 + 한 줄 + 읽어 보기)
/// 누르면 사이트 안내 글(외부 브라우저), x 면 영구 숨김. 닫으면 접히며 사라짐. 팁이 없으면 빈 자리 (여백 포함)
class GuideTipSlot extends ConsumerWidget {
  const GuideTipSlot({
    super.key,
    required this.placement,
    this.padding = EdgeInsets.zero,
    this.isSuppressed = false,
  });

  final GuideTipPlacement placement;

  /// 팁이 보일 때만 두는 바깥 여백
  final EdgeInsets padding;

  /// 같은 화면에 다른 안내 카드가 떠 있어 잠시 숨김 (닫은 기록은 안 남김)
  final bool isSuppressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = ref.watch(guideTipForPlacementProvider(placement));
    final l10n = context.l10n;
    return HomeNoticeSwitcher(
      child: tip == null || isSuppressed
          ? null
          : Padding(
              key: ValueKey(tip),
              padding: padding,
              child: ElumInfoCard(
                illustrationAsset: illustrationAssetOf(tip),
                title: _titleOf(tip, l10n),
                body: _bodyOf(tip, l10n),
                actionLabel: l10n.guideTipReadAction,
                onAction: () => _openArticle(context, tip),
                onTap: () => _openArticle(context, tip),
                closeLabel: l10n.guideTipDismissLabel,
                onClose: () => ref.read(dismissedGuideTipsProvider.notifier).dismiss(tip),
              ),
            ),
    );
  }

  // 외부 브라우저로 열기, 못 열면 실패 팝업 + 코드
  Future<void> _openArticle(BuildContext context, GuideTip tip) async {
    final url = toGuideArticleUrl(tip, context.appLocale.languageCode);
    final isOpened = await openNoticeLink(url);
    if (isOpened || !context.mounted) return;
    await showFailureMessage(context, sentence: context.l10n.guideTipOpenFailed, code: guideTipOpenFailedCode);
  }

  /// 팁 > 3D 그림 (팁마다 다른 그림, 같은 그림 반복 없음)
  static String illustrationAssetOf(GuideTip tip) => switch (tip) {
    GuideTip.actionCards => AppAssets.featureIconGuide,
    GuideTip.makeActionCards => AppAssets.abaTileShow,
    GuideTip.caregiverRole => AppAssets.abaTileHelp,
    GuideTip.taskAnalysis => AppAssets.abaTileSteps,
    GuideTip.rewards => AppAssets.featureIconReward,
  };

  static String _titleOf(GuideTip tip, AppLocalizations l10n) => switch (tip) {
    GuideTip.actionCards => l10n.guideTipActionCardsTitle,
    GuideTip.makeActionCards => l10n.guideTipMakeActionCardsTitle,
    GuideTip.caregiverRole => l10n.guideTipCaregiverRoleTitle,
    GuideTip.taskAnalysis => l10n.guideTipTaskAnalysisTitle,
    GuideTip.rewards => l10n.guideTipRewardsTitle,
  };

  static String _bodyOf(GuideTip tip, AppLocalizations l10n) => switch (tip) {
    GuideTip.actionCards => l10n.guideTipActionCardsBody,
    GuideTip.makeActionCards => l10n.guideTipMakeActionCardsBody,
    GuideTip.caregiverRole => l10n.guideTipCaregiverRoleBody,
    GuideTip.taskAnalysis => l10n.guideTipTaskAnalysisBody,
    GuideTip.rewards => l10n.guideTipRewardsBody,
  };
}

import 'package:flutter/material.dart';

import '../../../core/haptics/tap_haptics.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../../../core/widgets/pro_badge.dart';
import '../../../core/widgets/pro_upsell_button.dart';

/// Pro 기능 설명 시트 띄우기 > `Pro 알아보기` 를 눌렀으면 true (닫기 · 바깥 누름은 false)
Future<bool> showProFeatureExplainSheet(
  BuildContext context, {
  required String illustrationAsset,
  required String title,
  String? description,
  String? freeAlternativeLine,
  required bool canLearnPro,
}) async {
  final isLearnProChosen = await showElumGuideSheet<bool>(
    context: context,
    builder: (_) => ProFeatureExplainSheet(
      illustrationAsset: illustrationAsset,
      title: title,
      description: description,
      freeAlternativeLine: freeAlternativeLine,
      canLearnPro: canLearnPro,
    ),
  );
  return isLearnProChosen ?? false;
}

/// Pro 기능 설명 시트 (안내 뼈대): 3D 그림 > 무엇을 해 주는지 한 줄 > PRO 배지 > 왜 좋은지 한 줄 > (살 수 없으면) 지금 할 수 있는 길 > `Pro 알아보기` > 닫기
///
/// 흐름 안(카드 검토 · 그림 방식)에서 Pro 입구를 눌렀을 때 요금제 화면 대신 먼저 보임. 요금제 화면은 `Pro 알아보기` 를 고를 때만
class ProFeatureExplainSheet extends StatelessWidget {
  const ProFeatureExplainSheet({
    super.key,
    required this.illustrationAsset,
    required this.title,
    required this.canLearnPro,
    this.description,
    this.freeAlternativeLine,
  });

  /// 3D 기능 아이콘 PNG (AppAssets.featureIcon*)
  final String illustrationAsset;

  /// 무엇을 해 주는지 (요금제 화면 혜택 줄과 같은 문구)
  final String title;

  /// 왜 좋은지 한 줄 (없으면 자리 없음)
  final String? description;

  /// Pro 를 살 수 없을 때 지금 할 수 있는 길 (살 수 있으면 null)
  final String? freeAlternativeLine;

  /// `Pro 알아보기` 를 보일지 (판매 중 · 요금제 화면을 열 수 있음)
  final bool canLearnPro;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final freeAlternativeLine = this.freeAlternativeLine;
    return ElumGuidePanel(
      placement: ElumGuidePlacement.sheet,
      illustration: ElumGuideIllustration(asset: illustrationAsset, size: ElumGuideIllustrationSize.sheet),
      title: title,
      titleAccessory: const ProBadge(),
      description: description,
      // 살 수 없으면 지금 할 수 있는 길, 살 수 있으면 민트 `Pro 알아보기` (Pro 권유 버튼은 ProUpsellButton 하나)
      content: [
        if (freeAlternativeLine != null) ElumGuideNote(text: freeAlternativeLine),
        if (canLearnPro)
          ProUpsellButton(style: ProUpsellStyle.filled, onTap: withTapHaptic(() => Navigator.of(context).pop(true))),
      ],
      secondaryActions: [ElumSecondaryButton(label: l10n.commonClose, onTap: () => Navigator.of(context).pop(false))],
    );
  }
}

import 'package:flutter/widgets.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import 'top_bar_icon_button.dart';

/// 코치마크 다시 보기 `?` 버튼 (카드 검토 상단바 · 일과관리 머리)
///
/// 자리 24 안에 물음표 원 20 — 물음표 원은 테두리까지 꽉 찬 그림이라 24 로 그리면 옆 24 아이콘보다 커 보인다.
class CoachHelpButton extends StatelessWidget {
  const CoachHelpButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TopBarIconButton(
    iconAsset: AppAssets.iconQuestionCircle,
    semanticLabel: context.l10n.coachHelpLabel,
    onTap: onTap,
  );
}

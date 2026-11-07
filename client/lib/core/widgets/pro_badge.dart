import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../theme/theme_context_ext.dart';
import 'elum_label_chip.dart';

/// Pro 배지 단일 부품: 노란 바탕 + 검은 `Pro` (#1170)
///
/// Free 에게 보이는 Pro 입구(미리 보기 판 · 그림 방식 · 인쇄 디자인 칩 · 일과관리 입구 · 설정 줄)는 모두 이것만 씀
/// 노란색(`accentYellow`)·문구(`planProBadge`)는 이 파일 밖에서 쓰지 않음 (tool/design_rules.yaml `restricted_tokens`)
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ElumLabelChip(
      label: context.l10n.planProBadge,
      background: colors.accentYellow,
      foreground: colors.textPrimary,
    );
  }
}

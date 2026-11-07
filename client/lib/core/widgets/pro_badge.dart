import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/theme_context_ext.dart';
import 'elum_label_chip.dart';

/// Pro 배지 단일 부품: 노란 바탕 + 검은 `Pro` (#1170)
///
/// Free 에게 보이는 Pro 입구(미리 보기 판 · 그림 방식 · 인쇄 디자인 칩 · 일과관리 입구 · 설정 줄 · 일과 메뉴 줄 · 반복 줄 · 카드 그림 칩)는 모두 이것만 씀
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

/// 글자 뒤 [ProBadge] 한 줄: 글자가 길면 글자만 줄고 배지는 남음. [shouldShowProBadge] 가 false 면 글자만
///
/// 설정 줄 · 빠른 메뉴 줄 · 일과 상세 반복 줄 · 카드 그림 칩이 같은 간격으로 씀
class LabelWithProBadge extends StatelessWidget {
  const LabelWithProBadge({
    super.key,
    required this.label,
    required this.shouldShowProBadge,
  });

  /// 글자 위젯 (줄 수·말줄임·색은 부르는 쪽이 정함)
  final Widget label;
  final bool shouldShowProBadge;

  /// 글자 > 배지 간격
  static const _labelToBadge = 6.0;

  @override
  Widget build(BuildContext context) {
    if (!shouldShowProBadge) return label;
    // 글자 폭만큼만 차지 (칩처럼 폭이 정해지지 않은 자리에서도 늘어나지 않게)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: label),
        SizedBox(width: _labelToBadge.w),
        const ProBadge(),
      ],
    );
  }
}

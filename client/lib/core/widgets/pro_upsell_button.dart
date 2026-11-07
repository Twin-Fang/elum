import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import 'elum_floating_pill_button.dart';
import 'elum_text_link.dart';

/// 요금제 화면을 여는 버튼 모양 2개: 미리 보기 판의 주 버튼 · 화면 안 보조 안내의 글자 링크
enum ProUpsellStyle {
  /// 검은 알약 (미리 보기 판 [ProTeaser])
  filled,

  /// 밑줄 글자 (워터마크 안내 · 반복 시트처럼 다른 주 버튼 아래 보조 안내)
  link,
}

/// Pro 권유 버튼 단일 부품: 문구 `Pro 알아보기` 하나 + 모양 2개 (#1170)
///
/// 누르면 부르는 쪽이 `openPlanPaywall` 로 요금제 화면을 엶. 보이는 조건은 부르는 쪽 (`PlanAccess.shouldPromoteBenefit`)
/// 팝업 버튼은 팝업 부품 톤을 따름 (크레딧 부족 팝업, `ElumDialogAction`) — 문구 키만 같음
class ProUpsellButton extends StatelessWidget {
  const ProUpsellButton({
    super.key,
    required this.style,
    required this.onTap,
  });

  final ProUpsellStyle style;

  /// null 이면 누르지 못함 (저장 중)
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.planLearnPro;
    return switch (style) {
      ProUpsellStyle.filled => ElumFloatingPillButton(label: label, leading: null, onTap: onTap),
      ProUpsellStyle.link => ElumTextLink(label: label, onTap: onTap),
    };
  }
}

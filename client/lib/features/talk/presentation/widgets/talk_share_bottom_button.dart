import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';

/// 올리기 화면 아래 버튼 띠: 위 투명 > 아래 바탕색 그라데이션 + 버튼 (null 이면 꺼진다)
/// 본문 위에 겹쳐 두어 카드가 버튼 뒤로 흐려지며 지나간다 (시안 1870:9443 · 9444)
class TalkShareBottomButton extends StatelessWidget {
  const TalkShareBottomButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  /// 그라데이션 윗변 > 버튼 · 홈 표시줄 위 버튼 아래 (시안 16 · 56 - 34)
  static const _fadeAboveButton = 16.0;
  static const _buttonBottomExtra = 22.0;

  /// 띠 전체 높이 (본문이 마지막 줄을 버튼 위까지 올릴 아래 여백)
  static double heightOf(BuildContext context) =>
      _fadeAboveButton.h +
      context.space.buttonH.h +
      _buttonBottomExtra.h +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final background = context.colors.background;
    return Container(
      padding: EdgeInsets.fromLTRB(
        space.buttonMarginH.w,
        _fadeAboveButton.h,
        space.buttonMarginH.w,
        _buttonBottomExtra.h + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background.withValues(alpha: 0), background],
        ),
      ),
      child: ElumButton(label: label, loading: isLoading, onPressed: onPressed),
    );
  }
}

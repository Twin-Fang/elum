import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../assets/app_assets.dart';
import '../theme/theme_context_ext.dart';

/// 크레딧 그림 (장식): 낭독기는 읽지 않고 곁의 글이 `크레딧 N개` 를 말함
class CreditTicketIcon extends StatelessWidget {
  const CreditTicketIcon({super.key, required this.size});

  /// 가로 크기 (정사각 그림)
  final double size;

  @override
  Widget build(BuildContext context) =>
      Image.asset(AppAssets.creditTicket, width: size.w, height: size.w, excludeFromSemantics: true);
}

/// 크레딧 비용 표시 단일 부품: 글자 높이에 맞춘 크레딧 그림 + 글 (`🎫 1개` · `🎫 크레딧 없이, 오늘 2번 남았어요`)
///
/// 낭독기에는 [semanticLabel](없으면 [text]) 한 덩어리로 읽힘 (`크레딧 1개`). 무료일 때도 0 대신 지금 문구를 [text] 로 씀
class CreditCostLabel extends StatelessWidget {
  const CreditCostLabel({super.key, required this.text, this.semanticLabel, this.style, this.textAlign = TextAlign.center});

  final String text;

  /// 낭독 문구 (보이는 글이 숫자만일 때 `크레딧 1개`)
  final String? semanticLabel;

  /// 글 모양. 없으면 줄 글자 기본
  final TextStyle? style;
  final TextAlign textAlign;

  /// 그림 > 글 사이
  static const _iconToText = 6.0;

  @override
  Widget build(BuildContext context) {
    final textStyle = (style ?? context.typo.settingsTileLabel).copyWith(color: style?.color ?? context.colors.textPrimary);
    // 그림 크기는 글자 높이(배율 반영)에 맞춤
    final iconSize = MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 16) * (textStyle.height ?? 1.2);
    return Semantics(
      container: true,
      label: semanticLabel ?? text,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(AppAssets.creditTicket, width: iconSize, height: iconSize),
            SizedBox(width: _iconToText.w),
            Flexible(child: Text(text, textAlign: textAlign, style: textStyle)),
          ],
        ),
      ),
    );
  }
}

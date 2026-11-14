import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../text/keep_words.dart';

/// 어절 단위로 줄바꿈하는 글. 낭독기에는 표시가 섞이지 않은 원문을 읽게 함
class KeptText extends StatelessWidget {
  const KeptText(this.text, {super.key, required this.style, this.textAlign});

  final String text;
  final TextStyle style;

  /// 여러 줄일 때 정렬 (null 이면 시작 쪽)
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
    keepWords(text, locale: context.appLocale),
    semanticsLabel: text,
    style: style,
    textAlign: textAlign,
  );
}

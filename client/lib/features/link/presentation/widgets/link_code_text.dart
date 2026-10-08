import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 암호 여섯 글자. 3-3으로 묶고 가운데를 더 벌린다 (Figma 732:5710).
///
/// `Text` 하나에 `letterSpacing`을 주지 않는 이유 — 마지막 글자 뒤에도 자간이
/// 붙어 묶음이 왼쪽으로 치우친다. 글자를 낱개로 놓아야 가운데가 맞는다.
class LinkCodeText extends StatelessWidget {
  const LinkCodeText({
    super.key,
    required this.code,
    required this.dimmed,
    required this.letterGap,
    required this.groupGap,
  });

  final String code;
  final bool dimmed;
  final double letterGap;
  final double groupGap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typo.linkCode.copyWith(
      color: dimmed ? colors.textPlaceholder : colors.textPrimary,
    );
    final letters = code.split('');
    final half = letters.length ~/ 2;

    // 글꼴 2.0 이면 여섯 글자가 화면 폭을 100 넘는다. 폭에 맞춰 줄이기만 한다 —
    // 들어갈 때(글꼴 1.0)는 그대로라 시안 크기가 바뀌지 않는다.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, ch) in letters.indexed) ...[
            if (i > 0) SizedBox(width: (i == half ? groupGap : letterGap).w),
            Text(ch, style: style),
          ],
        ],
      ),
    );
  }
}

/// `코드 다시 만들기` 칩 (Figma 732:5718 — padding 10/20, r20).
class LinkRetryChip extends StatelessWidget {
  const LinkRetryChip({super.key, required this.onTap, this.label});

  final VoidCallback? onTap;

  /// 칩 글자. 비우면 `코드 다시 만들기`(시안 그대로)다.
  final String? label;

  static const _padV = 10.0;
  static const _padH = 20.0;
  static const _radius = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: _padV.h, horizontal: _padH.w),
        decoration: BoxDecoration(
          color: colors.linkRetryChipBg,
          borderRadius: BorderRadius.circular(_radius.r),
        ),
        child: Text(
          label ?? context.l10n.linkRetryChipLabel,
          style: context.typo.linkRetryChip.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}

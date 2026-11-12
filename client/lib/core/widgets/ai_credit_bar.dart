import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 남은 비율 막대 — 숫자와 **함께** 보인다(이슈: 막대만으로는 양을 모른다).
class AiCreditBar extends StatelessWidget {
  const AiCreditBar({super.key, required this.ratio, required this.color});

  final double ratio;
  final Color color;

  static const _height = 10.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular((_height / 2).h);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(color: context.colors.creditBarTrack),
        child: SizedBox(
          height: _height.h,
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

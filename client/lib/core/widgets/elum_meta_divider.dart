import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 글 정보 사이 1px 세로선 (`작성자 | 시각`, `보상 | 만든 사람`)
/// 앞뒤 간격은 쓰는 줄이 정함 (시안마다 6 · 8)
class ElumMetaDivider extends StatelessWidget {
  const ElumMetaDivider({super.key, required this.height, this.color});

  /// 시안 높이 (이야기 12, 홈 일과 줄 13)
  final double height;

  /// null 이면 기본 세로선 색 (#D9D3CF)
  final Color? color;

  /// 선 굵기 1px (배율 없이 머리카락 선)
  static const _thicknessPixels = 1.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _thicknessPixels,
      height: height.h,
      color: color ?? context.colors.metaDivider,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// 안내 창·시트 그림 부품: 그림 크기 2단계 · 맨 위 그림. 받는 순간 연출은 AppCelebration

/// 그림 크기 2단계: 창 96 · 시트 120
enum ElumGuideIllustrationSize {
  dialog(96),
  sheet(120);

  const ElumGuideIllustrationSize(this.extent);

  final double extent;
}

/// 맨 위 그림 (루미 · 크레딧 PNG)
class ElumGuideIllustration extends StatelessWidget {
  const ElumGuideIllustration({super.key, required this.asset, required this.size});

  final String asset;
  final ElumGuideIllustrationSize size;

  @override
  Widget build(BuildContext context) =>
      Image.asset(asset, height: size.extent.w, fit: BoxFit.contain, excludeFromSemantics: true);
}

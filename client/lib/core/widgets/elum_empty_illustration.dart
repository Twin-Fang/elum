import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../assets/app_assets.dart';

/// 목록이 비었을 때 문구 위에 놓는 루미 그림 (400×400 투명 PNG, 정사각형)
class ElumEmptyIllustration extends StatelessWidget {
  const ElumEmptyIllustration({super.key});

  static const _size = 160.0;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.notificationsEmptyLumi,
      width: _size.w,
      height: _size.w,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';

/// "secured by ELUM AI DLP" 신뢰 배지.
///
/// Figma Group 57/58(`418:4049` 등)에 화면 7개 전부 동일한 자리에 반복해서
/// 그려져 있다 — 일과 만들기 흐름 전체와 시작 화면 하단. 화면마다 좌표를
/// 베끼면 한 곳만 여백이 어긋나도 눈에 띈다.
class SecuredByDlpBadge extends StatelessWidget {
  const SecuredByDlpBadge({super.key});

  static const _textColor = Color(0xFF74757D);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(AppAssets.iconDlpLock, width: 16.w, height: 16.w),
        SizedBox(width: 4.w),
        Text(
          'secured by ELUM AI DLP',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
            color: _textColor,
          ),
        ),
      ],
    );
  }
}

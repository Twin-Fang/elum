import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';

/// 시작 화면의 병아리를 한 덩어리로 묶은 것 (이슈 #207).
///
/// 몸통·눈·부리가 **따로 있는 SVG**라, 시작 화면처럼 절대 좌표로 흩어 놓으면
/// 다른 화면에서 크기를 바꿀 때 얼굴만 제자리에 남는다. 실제로 로그인 화면에
/// 몸통만 옮겼더니 얼굴 없는 덩어리가 나왔고, 얼굴을 더하니 이번엔 버튼에 가렸다.
///
/// 시작 화면의 좌표(몸통 y=413 · 눈 y=573 · 부리 y=599)를 **서로의 거리**로 바꿔
/// 담았다. 통째로 키우거나 줄여도 얼굴이 따라온다.
class ElumChick extends StatelessWidget {
  const ElumChick({super.key, this.width});

  /// 없으면 설계 폭(393)을 쓴다.
  final double? width;

  /// 설계 기준 크기 — 몸통 위에서 부리 아래까지.
  static const _designWidth = 393.0;
  static const _designHeight = 260.0;

  /// 몸통 위를 0으로 두었을 때의 거리 (시작 화면 좌표에서 그대로 옮겼다).
  static const _eyeTop = 160.0;
  static const _beakTop = 186.0;
  static const _eyeLeft = 124.0;
  static const _eyeRight = 239.0;
  static const _beakLeft = 174.0;

  @override
  Widget build(BuildContext context) {
    final w = width ?? _designWidth;
    final scale = w / _designWidth;

    return SizedBox(
      width: w.w,
      height: (_designHeight * scale).h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: w.w,
            child: SvgPicture.asset(
              AppAssets.splashChickBody,
              width: w.w,
              fit: BoxFit.fitWidth,
            ),
          ),
          Positioned(
            left: (_eyeLeft * scale).w,
            top: (_eyeTop * scale).h,
            child: SvgPicture.asset(AppAssets.splashCharLeft, width: (30 * scale).w),
          ),
          Positioned(
            left: (_eyeRight * scale).w,
            top: (_eyeTop * scale).h,
            child: SvgPicture.asset(AppAssets.splashCharRight, width: (30 * scale).w),
          ),
          Positioned(
            left: (_beakLeft * scale).w,
            top: (_beakTop * scale).h,
            child: SvgPicture.asset(AppAssets.splashCenter, width: (45 * scale).w),
          ),
        ],
      ),
    );
  }
}

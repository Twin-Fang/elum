import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/widgets/app_pop_in.dart';

/// 일과 만들기 단계 머리 3D 그림 (64, 톡 튐): 입력 루미 얼굴 · 질문 전구 · 보상 별이 같은 자리 · 같은 크기
class RoutineFlowStepIcon extends StatelessWidget {
  const RoutineFlowStepIcon({super.key, required this.illustrationAsset});

  /// 3D 그림 PNG (AppAssets.featureIcon* · guardianProfileLumi)
  final String illustrationAsset;

  /// 한 변 64 (3D 그림은 둘레가 투명이라 48 이면 작아 보임)
  static const size = 64.0;

  /// 시안 반짝임(30×36) 자리보다 커진 만큼 위로 당기는 값 (제목 높이 유지)
  static const extraHeightOverSparkles = size - 36.0;

  /// 입력 화면 루미 얼굴 자리(48)보다 커진 만큼 위로 당기는 값
  static const extraHeightOverLumiFace = size - 48.0;

  @override
  Widget build(BuildContext context) => AppPopIn(
    child: Image.asset(
      illustrationAsset,
      width: size.w,
      height: size.w,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

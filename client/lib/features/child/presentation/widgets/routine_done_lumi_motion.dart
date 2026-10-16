import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';

/// 일과 완료 화면의 별 다섯 개와 루미: 등장(튀어 오름) > 대기(숨쉬기, 기울기, 별 반짝임·떠다님)
/// 움직임을 끄면 시안의 정지 모양(마지막 안착 모양)만 그린다.
class RoutineDoneLumiMotion extends StatefulWidget {
  const RoutineDoneLumiMotion({
    super.key,
    required this.isMotionEnabled,
    required this.toDesignX,
    required this.toDesignY,
  });

  /// false 이거나 시스템 동작 줄이기가 켜져 있으면 모든 움직임을 끈다.
  final bool isMotionEnabled;

  /// 시안 프레임 좌표 > 안전영역 안 좌표
  final double Function(double) toDesignX;
  final double Function(double) toDesignY;

  /// 시험에서 루미 자리를 찾는 열쇠
  static const lumiKey = ValueKey('routineDoneLumi');

  @override
  State<RoutineDoneLumiMotion> createState() => _RoutineDoneLumiMotionState();
}

/// 별: (에셋, 시안 상자 중심 x, y, 에셋 가로, 세로, 한 바퀴 안 반짝임 횟수, 시작 위상)
/// 중심은 시안 export 와 맞댄 값이고, 크기는 후광이 구워진 에셋 크기(3배 export / 3)다.
typedef _StarSpec = (String, double, double, double, double, int, double);

class _RoutineDoneLumiMotionState extends State<RoutineDoneLumiMotion>
    with SingleTickerProviderStateMixin {
  static const _stars = <_StarSpec>[
    (AppAssets.routineDoneStarGreen, 341.04, 130.5, 56.33, 54.67, 4, 0.0),
    (AppAssets.routineDoneStarOrange, 63.9, 230.2, 60.67, 60.67, 3, 0.35),
    (AppAssets.routineDoneStarRed, 237.15, 176.1, 45.33, 45.0, 5, 0.6),
    (AppAssets.routineDoneStarPink, 123.19, 127.19, 38.67, 38.67, 6, 0.15),
    (AppAssets.routineDoneStarPurple, 301.21, 248.21, 38.67, 38.67, 4, 0.8),
  ];

  /// 루미 숨쉬기 폭(px)과 한 바퀴 안 횟수 (12초 / 6 = 2초 주기)
  static const _breathAmplitude = 4.0;
  static const _breathCountPerLoop = 6;

  /// 루미 기울기: 한 바퀴에 2번, 각 6초 주기의 앞 30% 구간에서만 까딱인다 (발 밑 기준, 라디안)
  static const _tiltAmplitudeRadians = 0.05;
  static const _tiltCountPerLoop = 2;
  static const _tiltActiveRatio = 0.3;

  /// 별 크기 범위(0.9~1.1)와 밝기 하한, 떠다니는 폭(px)
  static const _starScaleAmplitude = 0.1;
  static const _starMinimumOpacity = 0.7;
  static const _starDriftAmplitude = 3.0;

  late final AnimationController _ambientLoop = AnimationController(
    vsync: this,
    duration: AppMotion.celebrationAmbientLoop,
  );

  bool get _isMotionOn =>
      widget.isMotionEnabled && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAmbientLoop();
  }

  @override
  void didUpdateWidget(RoutineDoneLumiMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAmbientLoop();
  }

  /// 움직임 켬 > 반복 시작, 끔 > 멈추고 정지 모양으로 되돌림
  void _syncAmbientLoop() {
    if (_isMotionOn) {
      if (!_ambientLoop.isAnimating) _ambientLoop.repeat();
    } else {
      _ambientLoop.stop();
      _ambientLoop.value = 0;
    }
  }

  @override
  void dispose() {
    _ambientLoop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMotionOn = _isMotionOn;
    return AnimatedBuilder(
      animation: _ambientLoop,
      builder: (context, _) {
        // 정지 모양은 위상 없이(null) 그린다
        final loopProgress = isMotionOn ? _ambientLoop.value : null;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < _stars.length; index++)
              _buildStar(_stars[index], index, loopProgress, isMotionOn),
            _buildLumi(loopProgress, isMotionOn),
          ],
        );
      },
    );
  }

  Widget _buildStar(
    _StarSpec spec,
    int index,
    double? loopProgress,
    bool isMotionOn,
  ) {
    final (asset, centerX, centerY, width, height, countPerLoop, phase) = spec;
    var scale = 1.0;
    var opacity = 1.0;
    var driftX = 0.0;
    var driftY = 0.0;
    if (loopProgress != null) {
      final wave = math.sin(2 * math.pi * (loopProgress * countPerLoop + phase));
      scale = 1 + _starScaleAmplitude * wave;
      opacity = _starMinimumOpacity + (1 - _starMinimumOpacity) * (wave + 1) / 2;
      // 별마다 다른 주기로 천천히 떠다닌다 (한 바퀴 안 1~2회)
      final driftAngle = 2 * math.pi * (loopProgress * (1 + index % 2) + phase);
      driftX = _starDriftAmplitude * math.sin(driftAngle);
      driftY = _starDriftAmplitude * math.cos(driftAngle);
    }

    Widget star = Transform.translate(
      offset: Offset(driftX.w, driftY.w),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Image.asset(asset, width: width.w, height: height.w),
        ),
      ),
    );
    if (isMotionOn) {
      // 등장: 별마다 시차를 두고 커지며 나타남
      star = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.celebrationEntrance,
        curve: Interval(0.1 * index, 0.5 + 0.1 * index, curve: AppMotion.springOut),
        builder: (context, t, child) =>
            Transform.scale(scale: t.clamp(0.0, 1.5), child: child),
        child: star,
      );
    }
    return Positioned(
      left: widget.toDesignX(centerX - width / 2),
      top: widget.toDesignY(centerY - height / 2),
      child: ExcludeSemantics(child: star),
    );
  }

  Widget _buildLumi(double? loopProgress, bool isMotionOn) {
    var breathOffset = 0.0;
    var tiltRadians = 0.0;
    if (loopProgress != null) {
      breathOffset =
          _breathAmplitude *
          math.sin(2 * math.pi * loopProgress * _breathCountPerLoop);
      final tiltProgress = (loopProgress * _tiltCountPerLoop) % 1;
      if (tiltProgress < _tiltActiveRatio) {
        // 구간 양끝에서 0 > 두 번 까딱 > 0
        final tiltWindow = tiltProgress / _tiltActiveRatio;
        tiltRadians =
            _tiltAmplitudeRadians *
            math.sin(math.pi * tiltWindow) *
            math.sin(4 * math.pi * tiltWindow);
      }
    }

    // 그룹 상자(Group 66): 시안 (116.55, 195), 152×160. 내보낸 그림과 눈웃음을 안에 얹는다.
    Widget lumi = Transform.translate(
      offset: Offset(0, breathOffset.w),
      child: Transform.rotate(
        angle: tiltRadians,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          key: RoutineDoneLumiMotion.lumiKey,
          width: 152.w,
          height: 160.w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 내보낸 그림은 그룹 상자보다 안쪽이라 (+4, +3) 옮긴다 (시안 export 와 맞댄 값)
              Positioned(
                left: 4.w,
                top: 3.w,
                child: Image.asset(
                  AppAssets.routineDoneLumi,
                  width: 144.33.w,
                  height: 157.33.w,
                ),
              ),
              // 눈웃음(시안 Vector 2, (207, 267))
              Positioned(
                left: (205.5 - 116.55).w,
                top: (265.5 - 195).w,
                child: SvgPicture.asset(
                  AppAssets.routineDoneWink,
                  width: 11.w,
                  height: 6.w,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (isMotionOn) {
      // 등장: 아래에서 튀어 올라 자리 잡음 (오버슛 스프링)
      lumi = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.celebrationEntrance,
        curve: AppMotion.springOut,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - t) * 160.w), child: child),
        ),
        child: lumi,
      );
    }
    return Positioned(
      left: widget.toDesignX(116.55),
      top: widget.toDesignY(195),
      child: ExcludeSemantics(child: lumi),
    );
  }
}

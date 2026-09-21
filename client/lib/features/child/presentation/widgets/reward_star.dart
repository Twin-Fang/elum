import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 보상 화면의 빛나는 별.
///
/// Figma `Group 46`(269×269) + 주변 작은 별 2개(38 / 30).
///
/// **별은 에셋이다.** 예전에는 `Icon(Icons.star_rounded)`로 그렸는데,
/// 그것은 Material 기본 글리프라 Figma의 그라데이션 별과 모양이 다르다.
/// 게다가 위젯 테스트에서는 아이콘 폰트가 없어 **네모로 렌더**됐다
/// (골든에서 발각 — client/CLAUDE.md §2 "일러스트를 코드로 그리지 않는다").
///
/// 애니메이션은 에셋을 `Transform.scale`로 감싸 그대로 유지한다 —
/// 등장 연출 때문에 코드로 그릴 이유는 없었다.
class RewardStar extends StatefulWidget {
  const RewardStar({super.key});

  /// 큰 별이 커지는 시간. 아동 화면이라 넉넉히 둔다.
  static const popDuration = Duration(milliseconds: 700);

  /// Figma 실측 — 큰 별 209
  /// 큰 별이 차지하는 폭. **후광까지 담긴 에셋 전체 기준이다.**
  ///
  /// 시안(309:4055)이 알려주는 209는 후광을 뺀 별 본체 크기다. 에셋에는 후광이
  /// 함께 들어 있어 그 값을 그대로 주면 별이 시안보다 10% 작아진다. 시안 그림에서
  /// 잰 본체 폭(177.5)에 에셋의 본체 비율을 맞춰 나온 값이다 (#297).
  static const mainSize = 230.9;

  @override
  State<RewardStar> createState() => _RewardStarState();
}

class _RewardStarState extends State<RewardStar>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RewardStar.popDuration,
  );

  /// 등장 연출이 끝난 뒤 이어지는 은은한 둥둥 떠다니는 반복 연출.
  /// 팝업(springOut)과 별개 컨트롤러라 서로 방해하지 않는다.
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: AppMotion.float,
  )..repeat();

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 동작 줄이기를 켰으면 애니메이션 없이 최종 상태로 둔다
    if (_reduceMotion) {
      _controller.value = 1;
      _floatController.stop();
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 별은 정사각형이라 가로세로 모두 .w
    return SizedBox(
      width: RewardStar.mainSize.w,
      height: RewardStar.mainSize.w,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _floatController]),
        builder: (context, _) {
          // elasticOut이라 1을 넘겼다가 돌아온다 — 터지는 느낌이 난다
          final t = AppMotion.springOut.transform(_controller.value);
          // 둥둥 뜨는 정도. 접근성 설정 시 0으로 고정해 흔들림이 없다.
          final floatT = _reduceMotion ? 0.0 : _floatController.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: _floatOffset(floatT, amplitude: 14.h, phase: 0),
                child: Transform.scale(
                  scale: t,
                  child: _Star(
                    size: RewardStar.mainSize.w,
                    glow: colors.rewardStarGlow,
                  ),
                ),
              ),
              // 작은 별들은 큰 별이 자리잡은 뒤 나타난다.
              //
              // 자리는 시안 노드 좌표(초록 76.7,308.9 · 보라 256.8,172.7)를 큰 별
              // 본체 중심(196.2, 245.5)에서 뺀 값이다. 에셋 전체 중심이 본체 중심보다
              // 5.7 아래라 그만큼 올려 준다 — 후광이 위아래로 고르게 붙지 않아서다.
              // 크기도 노드 값이 아니라 **에셋 크기**를 쓴다 (그림자 여백 포함).
              _Satellite(
                progress: _controller.value,
                begin: 0.5,
                offset: Offset(-100.5.w, 76.8.h) +
                    _floatOffset(floatT, amplitude: 10.h, phase: math.pi / 3),
                size: 48.7.w,
                asset: AppAssets.rewardStarGreen,
                glow: colors.starDecoGlowGreen,
              ),
              _Satellite(
                progress: _controller.value,
                begin: 0.7,
                offset: Offset(75.8.w, -63.3.h) +
                    _floatOffset(floatT, amplitude: 10.h, phase: math.pi),
                size: 38.7.w,
                asset: AppAssets.rewardStarPurple,
                glow: colors.starDecoGlowPurple,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 위쪽으로만 은은히 떠오르는 오프셋. sine 곡선이라 시작·끝이 매끄럽게
  /// 이어지되, 0~-amplitude 구간만 쓴다 — 아래로 내려가면 별 밑에 앉은
  /// 캐릭터(_RewardHero._charFrame)와 겹치기 때문에 원래 자리보다
  /// 아래로는 절대 내려가지 않는다.
  Offset _floatOffset(double t, {required double amplitude, required double phase}) {
    final wave = (math.sin(t * 2 * math.pi + phase) - 1) / 2; // 0 ~ -1
    return Offset(0, wave * amplitude);
  }
}

/// 큰 별. 후광·그림자·안쪽 하이라이트가 모두 에셋(PNG)에 구워져 있다.
class _Star extends StatelessWidget {
  const _Star({required this.size, required this.glow});

  final double size;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    // **높이를 주지 않는다** — 에셋이 264×255라 정사각형으로 묶으면 남는 쪽에
    // 여백이 생겨 별이 가운데로 밀린다 (#297).
    return Image.asset(AppAssets.starBig, width: size);
  }
}

/// 큰 별 주변의 작은 별. 투명도까지 에셋에 구워져 있어 덧씌우지 않는다.
class _Satellite extends StatelessWidget {
  const _Satellite({
    required this.progress,
    required this.begin,
    required this.offset,
    required this.size,
    required this.asset,
    required this.glow,
  });

  /// 전체 진행도 (0~1)
  final double progress;

  /// 이 별이 등장하기 시작하는 지점
  final double begin;

  final Offset offset;
  final double size;

  /// 별 에셋 경로. 색이 SVG 안에 들어 있어 따로 칠하지 않는다.
  final String asset;

  /// 이 별의 SVG 내장 feGaussianBlur 필터와 같은 색 (flutter_svg 미지원 대체).
  final Color glow;

  @override
  Widget build(BuildContext context) {
    // begin 이전에는 0, 이후 남은 구간에서 0→1
    final local = ((progress - begin) / (1 - begin)).clamp(0.0, 1.0);
    final scale = AppMotion.springOut.transform(local);

    return Transform.translate(
      offset: offset,
      child: Transform.scale(
        scale: scale,
        child: Image.asset(asset, width: size),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../guardian/data/routine_repository.dart';

/// Figma `아이_별`(364:8219) — 지금까지 모은 별을 보여준다.
///
/// 이룸이 홈의 별 배지를 탭하면 들어온다. 어두운 밤하늘에 큰 별과 누적 개수를
/// 띄운다. 뒤로가기만 있다.
///
/// **좌표는 Figma 절대값 그대로 쓴다.** 예전에는 `SafeArea` 안에 넣고 상태바
/// 높이를 52로 가정해 뺐는데, 실제 기기는 59라 화면 전체가 7씩 위로 떠 있었다.
/// 시안 프레임(852)이 상태바를 포함해 그려지므로, 안전영역을 만들지 않고
/// 절대 좌표를 그대로 옮기는 쪽이 어긋날 구석이 없다.
class ChildStarsScreen extends ConsumerWidget {
  const ChildStarsScreen({super.key});

  /// 주변 작은 별 일곱의 자리와 크기 (Figma 393×852 절대 좌표).
  ///
  /// **시안 PNG와 맞대 실측한 값이다.** Figma가 알려주는 `Star` 노드 좌표는
  /// 그림자까지 포함한 상자라 실제 그림보다 조금씩 크고 왼쪽 위로 밀려 있다.
  /// 에셋에도 그림자 여백이 함께 들어 있어, 노드 좌표를 그대로 쓰면 별이
  /// 서너 픽셀씩 어긋난다.
  static const _decoStars = [
    (index: 1, x: 49.0, y: 401.0, size: 48.7),
    (index: 2, x: 316.0, y: 350.0, size: 47.7),
    (index: 3, x: 313.0, y: 103.0, size: 56.3),
    (index: 4, x: 34.0, y: 199.5, size: 60.7),
    (index: 5, x: 215.0, y: 153.0, size: 45.3),
    (index: 6, x: 106.0, y: 103.0, size: 38.7),
    (index: 7, x: 282.0, y: 229.0, size: 38.7),
  ];

  /// 가운데 큰 별 — 후광까지 포함한 에셋이라 자리도 후광 기준이다.
  static const _bigStar = (x: 64.7, y: 195.7, size: 263.7);

  /// 뒤로가기 아이콘 자리 (Figma x=24 · y=87 · 24×24).
  static const _backIcon = 24.0;

  /// 이룸이가 누르는 화면이라 그림보다 훨씬 넓게 받는다 (아동 모드 규칙 64).
  /// 자리는 24 그대로 두고 그 위로만 덮어, 다른 요소를 밀지 않는다.
  static const _backTouch = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // 별 개수. 조회 실패해도 0으로 화면은 뜬다 (docs 원칙 6번)
    final stars = ref.watch(memberProvider).maybeWhen(
          data: (member) => member?.totalStars ?? 0,
          orElse: () => 0,
        );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Figma linear-gradient(180deg, #0C0D1A → #242634).
          // 보상 화면과 같은 밤하늘 세계관이라 토큰을 공유한다.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.rewardBackdropTop, colors.rewardBackdropBottom],
          ),
        ),
        child: Stack(
          children: [
            // 주변 작은 별 — 투명도까지 구워진 에셋이라 Opacity를 씌우지 않는다.
            for (final star in _decoStars)
              Positioned(
                left: star.x.w,
                top: star.y.h,
                // **높이를 주지 않는다.** 그림자 여백까지 담긴 에셋이라 정사각형이
                // 아닌데(예: 146×144) 정사각형으로 묶으면 남는 쪽에 여백이 생기고,
                // 그만큼 별이 가운데로 밀려 자리가 어긋난다.
                child: Image.asset(
                  AppAssets.starDeco(star.index),
                  width: star.size.w,
                ),
              ),
            // 가운데 큰 별 — 후광·그림자·안쪽 하이라이트가 모두 에셋에 들어 있다.
            Positioned(
              left: _bigStar.x.w,
              top: _bigStar.y.h,
              // 작은 별과 같은 이유로 높이를 주지 않는다 — 에셋이 264×255다.
              child: Image.asset(AppAssets.starBig, width: _bigStar.size.w),
            ),
            // 누적 개수 (Figma y=481 · 80/w800 · 노랑에서 흰색으로)
            Positioned(
              top: 481.h,
              left: 0,
              right: 0,
              child: Center(
                child: ShaderMask(
                  // 시안은 왼쪽 14% 지점까지 노랑을 유지하고 그 뒤로 흰색이 된다.
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [colors.starsNumberStart, colors.surface],
                    stops: const [0.14, 1],
                  ).createShader(bounds),
                  child: Text(
                    '$stars',
                    style:
                        context.typo.starsCount.copyWith(color: colors.surface),
                  ),
                ),
              ),
            ),
            // 안내 문구 (Figma y=594 · 20/w400 · 중앙)
            Positioned(
              top: 594.h,
              left: 0,
              right: 0,
              child: Text(
                '$stars개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!',
                textAlign: TextAlign.center,
                style: context.typo.cardDescription
                    .copyWith(color: colors.surface),
              ),
            ),
            // 뒤로가기 (Figma x=24 · y=87)
            Positioned(
              left: 24.w,
              top: 87.h,
              child: SizedBox(
                width: _backIcon.w,
                height: _backIcon.w,
                child: OverflowBox(
                  maxWidth: _backTouch.w,
                  maxHeight: _backTouch.w,
                  child: AppPressable(
                    onTap: () => context.pop(),
                    scaleDown: AppPressable.scaleIcon,
                    semanticLabel: ElumScaffold.backLabel,
                    child: SizedBox(
                      width: _backTouch.w,
                      height: _backTouch.w,
                      child: Center(
                        child: SvgPicture.asset(
                          AppAssets.iconBack,
                          width: _backIcon.w,
                          height: _backIcon.w,
                          colorFilter: ColorFilter.mode(
                            colors.surface,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

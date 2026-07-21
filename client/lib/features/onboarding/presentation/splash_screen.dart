import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../application/onboarding_notifier.dart';

/// Figma `시작` (238:1808) — 서비스 진입 화면.
///
/// 좌표·크기는 Figma 값(393×852 기준)을 그대로 쓰되 `.w`/`.h`/`.sp`로 감싼다.
/// ScreenUtil이 실제 화면 크기에 맞춰 비례 변환하므로 기기가 달라져도 구도가 유지된다.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // 이미 온보딩을 마쳤으면 다시 묻지 않는다
    final isDone = ref.read(localStorageProvider).isOnboardingCompleted;

    return Scaffold(
      body: Container(
        // 배경: 흰색 → 크림 (Figma linear-gradient 180deg, 40% 지점)
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.splashTop, colors.splashBottom],
            stops: const [0, 0.4],
          ),
        ),
        child: Stack(
          children: [
            // 병아리 몸통 — Figma y=413, 393×439.
            // 둥근 path와 방사형 그라데이션이 SVG 안에 있다.
            // 직접 그리면 사각형이 되므로 반드시 에셋을 쓴다.
            Positioned(
              left: 0,
              top: 413.h,
              width: 393.w,
              child: SvgPicture.asset(
                AppAssets.splashChickBody,
                width: 393.w,
                fit: BoxFit.fitWidth,
              ),
            ),

            // 덤불 (x=184, y=308, 113×111)
            Positioned(
              left: 184.w,
              top: 308.h,
              child: SvgPicture.asset(AppAssets.splashHill, width: 113.w),
            ),

            // 반짝이는 별 (x=281, y=340, 36×34)
            Positioned(
              left: 281.w,
              top: 340.h,
              child: SvgPicture.asset(AppAssets.splashStar, width: 36.w),
            ),

            // 언덕 위 캐릭터 실루엣 (각 30×32, y=573)
            Positioned(
              left: 124.w,
              top: 573.h,
              child: SvgPicture.asset(AppAssets.splashCharLeft, width: 30.w),
            ),
            Positioned(
              left: 239.w,
              top: 573.h,
              child: SvgPicture.asset(AppAssets.splashCharRight, width: 30.w),
            ),
            Positioned(
              left: 174.w,
              top: 599.h,
              child: SvgPicture.asset(AppAssets.splashCenter, width: 45.w),
            ),

            // 문구 (x=141 y=140 / x=92 y=168) — 가로 중앙 정렬
            Positioned(
              left: 0,
              top: 140.h,
              width: 393.w,
              child: Text(
                '오늘의 하루,',
                textAlign: TextAlign.center,
                style: context.typo.subtitle.copyWith(
                  color: colors.textSecondary,
                  fontSize: 20.sp,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 168.h,
              width: 393.w,
              child: Text(
                '차근차근 함께해요',
                textAlign: TextAlign.center,
                style: context.typo.headline.copyWith(
                  color: colors.splashTitle,
                  fontSize: 26.sp,
                ),
              ),
            ),

            // 로고 (x=115, y=214, 164×60) — 폰트가 아니라 SVG다
            Positioned(
              left: 115.w,
              top: 214.h,
              child: SvgPicture.asset(AppAssets.logo, width: 164.w),
            ),

            // 하단 CTA (x=16, y=675, 360×66)
            Positioned(
              left: 16.w,
              top: 675.h,
              width: 360.w,
              child: ElumButton(
                label: '시작하기',
                onPressed: () => context.go(
                  isDone ? Routes.guardian : Routes.onboardingName,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

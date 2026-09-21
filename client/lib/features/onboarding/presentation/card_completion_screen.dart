import 'package:flutter/material.dart';
import '../../guardian/presentation/widgets/aurora_background.dart';
import '../../../core/assets/app_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';

/// Figma `보호자_새로운 일과 만들기_완료` (425:4199)
///
/// AI가 행동 카드 생성을 완료한 상태를 1.5초 동안 표시 후 자동 다음 화면으로 이동.
class CardCompletionScreen extends ConsumerStatefulWidget {
  const CardCompletionScreen({super.key});

  @override
  ConsumerState<CardCompletionScreen> createState() =>
      _CardCompletionScreenState();
}

class _CardCompletionScreenState extends ConsumerState<CardCompletionScreen> {
  static const _displayDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    // 1.5초 후 자동 다음 화면으로 이동
    Future.delayed(_displayDuration, () {
      if (mounted) {
        context.go(Routes.guardian); // 보호자 홈으로 이동
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 시안(425:4199)은 **일과 만들기 입력과 같은 배치**다 — 반짝임 225 ·
    // 제목 285 · 진행도 363. 배경도 같다(#F7F2EF 위에 오로라 한 덩이).
    //
    // 전에는 배경을 초록에서 파랑으로 가는 그라데이션으로 화면 전체에 깔고,
    // 반짝임 자리에 별 글리프를 두고, 글자 크기를 직접 적어 두었다. 셋 다
    // 시안과 달랐다 (#297).
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: _CompletionLayout.topToSparkles),
                SvgPicture.asset(
                  AppAssets.iconSparklesLarge,
                  width: 30.w,
                  height: 36.h,
                ),
                SizedBox(height: _CompletionLayout.sparklesToTitle),
                Text(
                  '내용 정리가 모두\n완료됐어요',
                  textAlign: TextAlign.center,
                  style: context.typo.promptTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: _CompletionLayout.titleToProgress),
                Text(
                  '100% 완료!',
                  textAlign: TextAlign.center,
                  style: context.typo.promptBody.copyWith(
                    color: colors.promptMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 시안(425:4199)에서 뽑은 세로 값. 입력 화면과 같은 자리다.
class _CompletionLayout {
  /// 안전영역 아래부터 반짝임(225)까지.
  static double get topToSparkles => 166.h;

  /// 반짝임 → 제목(285).
  static double get sparklesToTitle => 24.h;

  /// 제목 → 진행도(363).
  static double get titleToProgress => 12.h;
}

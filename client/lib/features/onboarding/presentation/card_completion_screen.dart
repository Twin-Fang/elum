import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/secured_by_dlp_badge.dart';

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
    return Scaffold(
      body: Container(
        width: 393.w,
        height: 852.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF78FFB0), // 초록
              const Color(0xFF0099FF), // 파란
            ],
          ),
        ),
        child: Stack(
          children: [
            // 콘텐츠
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 별 아이콘
                    Container(
                      width: 48.w,
                      height: 48.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: Icon(
                        Icons.star,
                        size: 48.w,
                        color: const Color(0xFF1a1a1a),
                      ),
                    ),
                    SizedBox(height: 48.h),

                    // 제목
                    Text(
                      '내용 정리가 모두\n완료됐어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1a1a1a),
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // 진행도
                    Text(
                      '100% 완료!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFFA0A0A0),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // DLP 배지 (하단)
            Positioned(
              bottom: 32.h,
              left: 0,
              right: 0,
              child: Center(
                child: const SecuredByDlpBadge(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

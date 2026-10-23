import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../logger/app_logger.dart';
import '../theme/theme_context_ext.dart';
import '../widgets/app_pressable.dart';
import 'dev_simulation.dart';

/// 강제 업데이트·점검 화면의 `그냥 계속하기` (개발자 도구 빌드만)
/// 누르면 앱을 끌 때까지 게이트 통과
class DevSkipNoticeButton extends StatelessWidget {
  const DevSkipNoticeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: () {
        AppLogger.info('[dev app status] blocking notice skipped');
        DevSimulation.isBlockingNoticeSkipped.value = true;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Text(
          '테스트 빌드 · 그냥 계속하기',
          textAlign: TextAlign.center,
          style: context.typo.promptBody.copyWith(
            color: colors.textSecondary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

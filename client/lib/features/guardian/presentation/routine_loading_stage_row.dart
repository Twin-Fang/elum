import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../domain/routine_stage.dart';

/// 체크 표시 + 문구 한 줄.
///
/// 아래에서 위로 올라오며 나타난다. 끝난 단계는 원이 채워지고 문구가 진해진다.
class RoutineLoadingStageRow extends StatelessWidget {
  const RoutineLoadingStageRow({
    super.key,
    required this.stage,
    required this.isDone,
    required this.isVisible,
  });

  final RoutineStage stage;
  final bool isDone;
  final bool isVisible;

  /// Figma 실측 — 체크 원 20×20
  static const _dotSize = 20.0;

  /// 등장할 때 아래에서 올라오는 거리
  static const _riseFrom = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 자리는 처음부터 잡아둔다. 나타날 때 높이가 늘면 아래 스텝이 밀려
    // 이미 뜬 줄까지 함께 움직인다.
    return AnimatedOpacity(
      opacity: isVisible ? 1 : 0,
      duration: AppMotion.slow,
      curve: AppMotion.entry,
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, _riseFrom / _dotSize),
        duration: AppMotion.slow,
        curve: AppMotion.decelerate,
        child: Row(
          children: [
            SizedBox(
              width: _dotSize.w,
              height: _dotSize.w,
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                child: isDone
                    ? Container(
                        key: const ValueKey('done'),
                        decoration: BoxDecoration(
                          color: colors.stageDone,
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(5.w),
                        child: SvgPicture.asset(AppAssets.iconCheck),
                      )
                    // 지금 진행 중인 단계는 원이 돌아간다.
                    //
                    // Figma 262:4736 `Ellipse 22`는 정지된 테두리 원이지만,
                    // 그대로 두면 완료도 대기도 아닌 상태가 멈춰 보인다.
                    // 서버 응답이 늦으면 이 단계에 수 초간 머무르므로
                    // 움직임이 있어야 진행 중임이 전달된다.
                    : SizedBox.square(
                        key: const ValueKey('pending'),
                        dimension: _dotSize.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.w,
                          // Figma 원의 테두리 색을 그대로 쓴다
                          color: colors.stagePending,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
              ),
            ),
            // Figma: 아이콘 우측(x=20) → 문구 좌측(x=28)
            SizedBox(width: 8.w),
            // 색만 바뀌므로 문구가 갑자기 진해지지 않고 서서히 넘어간다
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.normal,
                curve: AppMotion.standard,
                style: context.typo.stageLabel.copyWith(
                  color: isDone ? colors.stageDone : colors.stagePendingText,
                ),
                child: Text(stage.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

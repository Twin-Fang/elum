import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import 'coach_help_button.dart';

/// 뒤로가기 + 홈 (Figma x=24 / x=72, y=87)
class RoutineFlowTopBar extends StatelessWidget {
  const RoutineFlowTopBar({
    super.key,
    this.onBack,
    required this.onHome,
    required this.showDraft,
    required this.onDraft,
    this.onHelp,
  });

  final VoidCallback? onBack;

  /// 오른쪽 `임시저장`. 홈과 같은 확인을 거친다.
  final bool showDraft;
  final VoidCallback onDraft;

  /// 홈도 나가는 길이다 — 뒤로가기와 같은 확인을 거친다.
  final VoidCallback onHome;

  /// 오른쪽 `?` (사용법 다시 보기). null 이면 그리지 않는다 — 카드 검토 화면만 넘긴다
  final VoidCallback? onHelp;

  /// `?` ↔ `임시저장` 누름 영역 사이
  static const _helpToDraftGap = 4.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 시안(262:4766)은 버튼 상자(40)가 y=67, 아이콘(24)이 y=75 에서 시작한다.
      // 안전영역(59) 안에서 16 이다 (시안 67).
      //
      // **아래에 12 를 더 준다.** 버튼만 올라갔고 아래 내용은 시안에서 제자리다.
      // 위 여백만 줄이면 상단바가 낮아져 화면 전체가 12 위로 뜬다.
      padding: EdgeInsets.only(
        left: context.space.screenH,
        top: 16.h,
        bottom: 12.h,
      ),
      child: Row(
        children: [
          if (onBack != null)
            AppPressable(
              onTap: onBack,
              scaleDown: AppPressable.scaleIcon,
              // 일과 만들기 흐름 화면 전부가 이 상단바를 쓴다 — 여기가 비면 다 빈다
              semanticLabel: context.l10n.commonBack,
              // 정사각형 아이콘이라 가로세로 모두 .w
              // 자리는 아이콘 크기 그대로 두고 **그 위로** 40×40 누름 영역을 덮는다.
              // 자리째 키우면 상단바가 높아져 화면 전체가 아래로 밀린다.
              child: SizedBox(
                width: 24.w,
                height: 24.w,
                child: OverflowBox(
                  maxWidth: 40.w,
                  maxHeight: 40.w,
                  child: SizedBox(
                    width: 40.w,
                    height: 40.w,
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.iconBack,
                        width: 24.w,
                        height: 24.w,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(width: 24.w),
          // 뒤로가기 자리(24~48) → 집 상자(시안 x=74). 24를 띄우면 2가 모자란다.
          SizedBox(width: 26.w),
          AppPressable(
            onTap: onHome,
            scaleDown: AppPressable.scaleIcon,
            semanticLabel: context.l10n.routineFlowHomeLabel,
            // 자리는 아이콘 크기 그대로 두고 **그 위로** 40×40 누름 영역을 덮는다.
            // 자리째 키우면 상단바가 높아져 화면 전체가 아래로 밀린다.
            child: SizedBox(
              width: 24.w,
              height: 24.w,
              child: OverflowBox(
                maxWidth: 40.w,
                maxHeight: 40.w,
                child: SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: Center(
                    child: SvgPicture.asset(
                      AppAssets.iconHome,
                      width: 24.w,
                      height: 24.w,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (onHelp != null || showDraft) const Spacer(),
          if (onHelp != null) ...[
            CoachHelpButton(onTap: onHelp!),
            SizedBox(width: (showDraft ? _helpToDraftGap : 16.0).w),
          ],
          if (showDraft) ...[
            // 시안 1173:5589 — 터치 영역 72×40 @ x=305(오른쪽 여백 16), 글자 16/w600.
            // 자리는 아이콘 높이 그대로 두고 **그 위로** 40 높이 누름 영역을 덮는다.
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: AppPressable(
                onTap: onDraft,
                semanticLabel: context.l10n.routineFlowDraftLabel,
                child: SizedBox(
                  width: 72.w,
                  height: 24.w,
                  child: OverflowBox(
                    maxWidth: 72.w,
                    maxHeight: 40.w,
                    child: SizedBox(
                      width: 72.w,
                      height: 40.w,
                      // 글꼴을 키우면 `임시저 / 장` 으로 꺾여 둘째 줄이 잘린다 — 한 줄로 줄인다
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.l10n.routineFlowDraftLabel,
                            maxLines: 1,
                            softWrap: false,
                            style: context.typo.topBarAction.copyWith(
                              color: context.colors.topBarActionText,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

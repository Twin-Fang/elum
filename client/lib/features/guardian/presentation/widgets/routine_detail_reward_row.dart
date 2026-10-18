import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/routine.dart';

/// 보상 줄. **정하지 않았어도 그린다**.
///
/// 없다고 줄째 숨기면 보상을 넣을 수 있다는 것조차 보이지 않는다.
/// 시안(980:5174)은 빈 칸 대신 **없다고 말하고**
/// 별을 흐리게 해 채울 수 있는 자리임을 보여준다. 줄째 없애면 보상을 넣을 수
/// 있다는 것조차 보이지 않는다.
///
/// **뱃지 + 카드로 둔다**. 시안(956:4084)이 검은 뱃지에 별을 넣어
/// 단계와 같은 짜임으로 그렸다. 뱃지 색과 별이 이미 "이건 단계가
/// 아니다"를 말해 주므로 `다 하면`이라는 말은 뺀다.
class RoutineDetailRewardRow extends StatelessWidget {
  const RoutineDetailRewardRow({super.key, required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    // 보상을 아직 정하지 않았어도 줄은 그린다. 줄째 없애면 보상을 넣을 수
    // 있다는 것조차 보이지 않는다. 시안(980:5174)은 **글자로** 알린다 —
    // 빈 칸이 아니라 "없어요"라고 말해 준다.
    final hasReward = routine.hasReward;

    final rewardText = Text(
      hasReward
          ? routine.rewardText.trim()
          : context.l10n.routineDetailNoReward,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: typo.sheetStepTitle.copyWith(
        color: hasReward ? colors.textPrimary : colors.rewardEmptyLabel,
      ),
    );

    // **위 여백을 주지 않는다.** 단계 줄마다 아래 8 이 붙어 있어 여기서 또 주면
    // 마지막 단계와 보상 사이만 16 이 된다 (시안은 8).
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // 단계 번호 자리에 검은 뱃지를 둔다. 폭이 같아 줄이 나란히 서고,
          // 색과 별로 "이건 단계가 아니라 보상"이 읽힌다 (Figma 963:4423).
          Container(
            width: 40.w,
            height: 68.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.rewardBadgeTop, colors.rewardBadgeBottom],
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            // 정하지 않았으면 별을 흐리게 — 채울 수 있는 자리임을 보여준다.
            // **별은 흐리게 하지 않는다.** 시안(`980:5174`)의 별은 보상이 없을
            // 때도 선명하다 — 흐리게 한 건 시안을 잘못 읽은 것이었다.
            // 비었다는 것은 **글자가** 말해 준다.
            child: SvgPicture.asset(
              AppAssets.rewardBadgeStar,
              width: 25.w,
              height: 24.w,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Container(
              height: 68.h,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              decoration: BoxDecoration(
                color: colors.editChipBg,
                borderRadius: BorderRadius.circular(20.r),
              ),
              // 보상 글은 일과 언어, 비었다는 안내는 화면 문구라 따로 둔다
              child: hasReward
                  ? ContentLocale(language: routine.language, child: rewardText)
                  : rewardText,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_meta_divider.dart';
import '../../../../shared/models/routine.dart';

/// 일과 줄 둘째 줄: `완료 시  유튜브 시청 20분 | 엄마` (시안 931:3896)
/// 보상·만든 사람 중 있는 것만, 둘 다 있으면 사이에 세로선
///
/// 라벨과 값이 같은 크기라 굵기로만 갈림 (크기까지 다르면 한 문장으로 안 읽힘)
/// 보상이 길면 보상만 줄어들고 만든 사람은 끝까지 보임
class RoutineTileMetaLine extends StatelessWidget {
  const RoutineTileMetaLine({
    super.key,
    required this.routine,
    this.creatorName,
  });

  final Routine routine;

  /// 만든 사람 호칭. null 이면 세로선과 함께 자리도 없음
  final String? creatorName;

  /// 보상이나 만든 사람 중 하나라도 있어 이 줄을 그리는가
  static bool hasContent(Routine routine, String? creatorName) =>
      routine.hasReward || creatorName != null;

  /// 시안 실측: `완료 시`(68~105) > 값(111~) 6 · 값 끝 > 세로선 6 · 세로선 > 이름 6, 세로선 높이 13
  static const _labelGap = 6.0;
  static const _dividerGap = 6.0;
  static const _dividerHeight = 13.0;

  /// 이름이 길 때 보상 자리를 다 먹지 않게 막는 폭 (13pt 기준 한글 6자)
  static const _creatorNameMaxWidth = 80.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final labelStyle = typo.routineTileMeta.copyWith(
      color: colors.routineTileLabel,
    );
    final creatorName = this.creatorName;
    final hasReward = routine.hasReward;

    return Row(
      children: [
        // 보상 (라벨 400 회색 + 값 500 70% 검정)
        if (hasReward) ...[
          Text(context.l10n.routineTileRewardLabel, style: labelStyle),
          SizedBox(width: _labelGap.w),
          Flexible(
            child: ContentLocale(
              language: routine.language,
              child: Text(
                routine.rewardText.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.routineTileReward.copyWith(
                  color: colors.routineTileReward,
                ),
              ),
            ),
          ),
        ],
        // 만든 사람 (라벨과 같은 400 회색)
        if (creatorName != null) ...[
          if (hasReward) ...[
            SizedBox(width: _dividerGap.w),
            const ElumMetaDivider(height: _dividerHeight),
            SizedBox(width: _dividerGap.w),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _creatorNameMaxWidth.w),
            child: Text(
              creatorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      ],
    );
  }
}

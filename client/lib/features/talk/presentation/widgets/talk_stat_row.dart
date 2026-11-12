import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_meta_divider.dart';
import '../../domain/talk_post.dart';

/// 피드 카드 숫자 줄: 도움돼요 > 댓글 > 가져감, 아이콘 + 이름 붙은 숫자 (`👍 도움돼요 2 · 💬 댓글 1 · ⬇ 2명 가져감`, #1301)
/// 숫자만으로는 ⬇ 가 `가져감`인지 몰라 이름을 붙인다. 좁은 인기 카드에서는 줄을 넘겨 감싼다
/// [authorName] 이 있으면 세로선 + 작성자 이름을 뒤에 붙인다 (최신 글 카드)
class TalkStatRow extends StatelessWidget {
  const TalkStatRow({super.key, required this.post, this.authorName});

  final TalkPostSummary post;
  final String? authorName;

  /// 항목 사이 · 줄 사이 · 세로선 > 이름 · 세로선 높이
  static const _itemGap = 12.0;
  static const _lineGap = 6.0;
  static const _dividerGap = 8.0;
  static const _dividerHeight = 12.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authorName = this.authorName;
    return Wrap(
      spacing: _itemGap.w,
      runSpacing: _lineGap.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TalkStatItem(
          iconAsset: AppAssets.iconThumbsUp,
          label: l10n.talkHelpfulCount(post.helpfulCount),
        ),
        TalkStatItem(
          iconAsset: AppAssets.navComment,
          label: l10n.talkCommentCount(post.commentCount),
        ),
        TalkStatItem(
          iconAsset: AppAssets.iconDownload,
          label: l10n.talkPopularImportCount(post.importCount),
        ),
        // 세로선 + 작성자 (자리가 모자라면 숫자 뒤 줄로 넘어간다)
        if (authorName != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElumMetaDivider(
                height: _dividerHeight,
                color: context.colors.talkCardBorder,
              ),
              SizedBox(width: _dividerGap.w),
              ConstrainedBox(
                // 긴 닉네임은 말줄임
                constraints: BoxConstraints(maxWidth: _authorMaxWidth.w),
                child: Text(
                  authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.talkMeta.copyWith(
                    color: context.colors.talkMetaText,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// 작성자 이름 최대 폭
  static const _authorMaxWidth = 96.0;
}

/// 아이콘 + 이름 붙은 숫자 한 쌍 (`👍 도움돼요 2`). 피드 카드와 상세가 같이 쓴다
class TalkStatItem extends StatelessWidget {
  const TalkStatItem({
    super.key,
    required this.iconAsset,
    required this.label,
    this.iconSize = _defaultIconSize,
    this.labelStyle,
  });

  final String iconAsset;
  final String label;

  /// 아이콘 한 변 (기본 14)
  final double iconSize;

  /// 글자 결. null 이면 피드 숫자 줄 결([AppTypography.talkStatLabel])
  final TextStyle? labelStyle;

  static const _defaultIconSize = 14.0;
  static const _iconToLabel = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 아이콘은 글자와 같은 회색 (연회색 #CACACA 는 거의 안 보였다)
        SvgPicture.asset(
          iconAsset,
          width: iconSize.w,
          height: iconSize.w,
          excludeFromSemantics: true,
          colorFilter: ColorFilter.mode(colors.talkMetaText, BlendMode.srcIn),
        ),
        SizedBox(width: _iconToLabel.w),
        Text(
          label,
          style: (labelStyle ?? context.typo.talkStatLabel).copyWith(
            color: colors.talkMetaText,
          ),
        ),
      ],
    );
  }
}

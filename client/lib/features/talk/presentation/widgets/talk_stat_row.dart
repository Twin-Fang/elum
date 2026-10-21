import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/talk_post.dart';

/// 피드 카드 숫자 줄: 도움돼요 > 댓글 > 가져감 (아이콘 10 + 숫자 12, 시안 1783:6675)
/// [authorName] 이 있으면 세로선 + 작성자 이름을 뒤에 붙인다 (최신 글 카드)
class TalkStatRow extends StatelessWidget {
  const TalkStatRow({super.key, required this.post, this.authorName});

  final TalkPostSummary post;
  final String? authorName;

  /// 항목 사이 · 세로선 좌우 (시안: 도움돼요 0 > 댓글 35 > 가져감 65, 세로선 앞뒤 8)
  static const _itemGap = 10.0;
  static const _dividerGap = 8.0;
  static const _dividerHeight = 12.0;
  static const _dividerWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authorName = this.authorName;
    return Row(
      children: [
        _StatItem(
          iconAsset: AppAssets.iconThumbsUp,
          count: post.helpfulCount,
          semanticLabel: l10n.talkHelpfulCount(post.helpfulCount),
        ),
        SizedBox(width: _itemGap.w),
        _StatItem(
          iconAsset: AppAssets.navComment,
          count: post.commentCount,
          semanticLabel: l10n.talkCommentCount(post.commentCount),
        ),
        SizedBox(width: _itemGap.w),
        _StatItem(
          iconAsset: AppAssets.iconDownload,
          count: post.importCount,
          semanticLabel: l10n.talkPopularImportCount(post.importCount),
        ),
        if (authorName != null) ...[
          SizedBox(width: _dividerGap.w),
          Container(
            width: _dividerWidth,
            height: _dividerHeight.h,
            color: context.colors.talkCardBorder,
          ),
          SizedBox(width: _dividerGap.w),
          Flexible(
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
      ],
    );
  }
}

/// 아이콘 + 숫자 한 쌍. 읽기 프로그램에는 `도움돼요 3` 처럼 이름과 함께 읽힌다
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.iconAsset,
    required this.count,
    required this.semanticLabel,
  });

  final String iconAsset;
  final int count;
  final String semanticLabel;

  static const _iconSize = 10.0;
  static const _iconToCount = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            iconAsset,
            width: _iconSize.w,
            height: _iconSize.w,
            colorFilter: ColorFilter.mode(colors.talkMetaIcon, BlendMode.srcIn),
          ),
          SizedBox(width: _iconToCount.w),
          Text(
            '$count',
            style: context.typo.talkMeta.copyWith(color: colors.talkMetaText),
          ),
        ],
      ),
    );
  }
}

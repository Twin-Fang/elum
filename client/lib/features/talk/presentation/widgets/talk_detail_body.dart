import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/talk_post.dart';
import 'talk_category_badge.dart';
import 'talk_detail_parts.dart';
import 'talk_step_cards.dart';

/// 상세 본문 (시안 1783:7172 · 1813:7718): 분류 · 카드 수 칩 > 제목 > 작성 정보 > 한마디
/// > 보기 전환 > 카드(크게 보기 | 한 눈에 보기) > 일과로 가져오기 > 도움돼요 · 댓글 수
/// 보기 전환은 이 화면 안에서만 기억한다 (다시 들어오면 크게 보기)
class TalkDetailBody extends StatefulWidget {
  const TalkDetailBody({
    super.key,
    required this.post,
    required this.onHelpfulPressed,
    required this.onImportPressed,
  });

  final TalkPostDetail post;
  final VoidCallback onHelpfulPressed;
  final VoidCallback onImportPressed;

  @override
  State<TalkDetailBody> createState() => _TalkDetailBodyState();
}

class _TalkDetailBodyState extends State<TalkDetailBody> {
  bool _isGridView = false;

  /// 머리 줄 > 칩 > 제목 > 작성 정보 > 한마디 > 전환 칩 > 카드 > 버튼 간격 (시안 20 · 12 · 12 · 24 · 32 · 24 · 32)
  /// 제목 > 작성 정보는 8: 제목 줄 높이 1.2 가 시안(1.0)보다 4 높아 그만큼 뺀다
  static const _headerToChips = 20.0;
  static const _chipGap = 8.0;
  static const _chipsToTitle = 12.0;
  static const _titleToPosted = 8.0;
  static const _postedToNote = 24.0;
  static const _noteToToggle = 32.0;
  static const _toggleToCards = 24.0;
  static const _cardsToImport = 32.0;
  static const _importToHelpful = 24.0;

  /// 가져오기 버튼 좌우 (시안 16)
  static const _buttonInset = 16.0;

  void _toggleView() => setState(() => _isGridView = !_isGridView);

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final category = post.category;
    final note = post.note;
    final textInset = EdgeInsets.symmetric(horizontal: space.screenH.w);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: _headerToChips.h),
        // 분류 · 카드 수 칩 (분류 없는 글은 카드 수만)
        Padding(
          padding: textInset,
          child: Row(
            children: [
              if (category != null) ...[
                TalkCategoryBadge(label: category.labelOf(l10n)),
                SizedBox(width: _chipGap.w),
              ],
              TalkCategoryBadge(
                label: l10n.talkDetailCardCountChip(post.stepCount),
                iconAsset: AppAssets.iconPlayingCards,
              ),
            ],
          ),
        ),
        SizedBox(height: _chipsToTitle.h),
        Padding(
          padding: textInset,
          child: Text(
            post.title,
            style: typo.talkDetailTitle.copyWith(color: colors.talkTitleText),
          ),
        ),
        SizedBox(height: _titleToPosted.h),
        Padding(
          padding: textInset,
          child: TalkDetailPostedRow(
            authorName: post.authorNickname ?? l10n.talkAuthorFallback,
            createdAt: post.createdAt,
          ),
        ),
        // 한마디 전문 (없으면 줄째 뺀다)
        if (note != null && note.isNotEmpty) ...[
          SizedBox(height: _postedToNote.h),
          Padding(
            padding: textInset,
            child: Text(
              note,
              style: typo.talkDetailNote.copyWith(color: colors.talkTitleText),
            ),
          ),
        ],
        SizedBox(height: _noteToToggle.h),
        Padding(
          padding: textInset,
          child: Align(
            alignment: Alignment.centerRight,
            child: TalkDetailViewToggle(
              isGridView: _isGridView,
              onToggled: _toggleView,
            ),
          ),
        ),
        SizedBox(height: _toggleToCards.h),
        // 보기를 바꾸면 카드가 툭 바뀌지 않게 서서히
        AnimatedSwitcher(
          duration: AppMotion.fast,
          child: TalkStepCards(
            key: ValueKey(_isGridView),
            postId: post.id,
            steps: post.steps,
            isGridView: _isGridView,
          ),
        ),
        SizedBox(height: _cardsToImport.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _buttonInset.w),
          child: TalkDetailImportButton(
            isImported: post.isImportedByMe,
            onPressed: widget.onImportPressed,
          ),
        ),
        SizedBox(height: _importToHelpful.h),
        // 도움돼요 · 댓글 수 (시안에 아직 자리가 없어 버튼 아래 둔다)
        Padding(
          padding: textInset,
          child: Row(
            children: [
              TalkHelpfulButton(
                count: post.helpfulCount,
                isSelected: post.isHelpfulByMe,
                onPressed: widget.onHelpfulPressed,
              ),
              SizedBox(width: space.sm.w),
              Text(
                l10n.talkCommentCount(post.commentCount),
                style: typo.tileLabel.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

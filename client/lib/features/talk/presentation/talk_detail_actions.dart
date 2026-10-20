import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../application/talk_comment_controller.dart';
import '../application/talk_detail_controller.dart';
import '../application/talk_rules_provider.dart';
import '../domain/talk_comment.dart';
import '../domain/talk_post.dart';
import '../domain/talk_screen_codes.dart';
import 'widgets/talk_block_dialog.dart';
import 'widgets/talk_delete_dialogs.dart';
import 'widgets/talk_edit_sheet.dart';
import 'widgets/talk_more_menu.dart';
import 'widgets/talk_report_sheet.dart';
import 'widgets/talk_rules_sheet.dart';

/// 상세 화면의 동작 흐름: 메뉴 > 확인·시트 > 요청 > 안내(토스트·실패 팝업)
/// 화면(State)이 만들어 쓰며, 닫힌 뒤에도 안내가 뜨도록 토스트 대상은 요청 전에 잡아 둔다
class TalkDetailActions {
  TalkDetailActions({
    required this.context,
    required this.ref,
    required this.postId,
  });

  final BuildContext context;
  final WidgetRef ref;
  final String postId;

  TalkDetailController get _detail =>
      ref.read(talkDetailControllerProvider(postId).notifier);
  TalkCommentController get _comments =>
      ref.read(talkCommentControllerProvider(postId).notifier);

  /// 도움이 됐어요 누르기: 실패하면 되돌려진 뒤 에러 코드가 붙은 팝업으로 알린다
  Future<void> toggleHelpful() async {
    final failedText = context.l10n.talkHelpfulFailed;
    try {
      await _detail.toggleHelpful();
    } catch (e) {
      if (!context.mounted) return;
      await showFailure(
        context,
        e,
        fallback: failedText,
        fallbackCode: TalkScreenCodes.detail,
      );
    }
  }

  /// 글 ⋯ 메뉴 > 고른 동작 실행
  Future<void> openPostMenu(TalkPostDetail post) async {
    final action = await showTalkPostMenu(context, isMine: post.isMine);
    if (action == null || !context.mounted) return;
    switch (action) {
      case TalkPostMenuAction.report:
        await _reportPost();
      case TalkPostMenuAction.block:
        await _blockPostAuthor(post);
      case TalkPostMenuAction.edit:
        await _editPost(post);
      case TalkPostMenuAction.takeDown:
        await _takeDownPost();
    }
  }

  /// 댓글 길게 누르기 메뉴 > 고른 동작 실행
  Future<void> openCommentMenu(TalkComment comment) async {
    final action = await showTalkCommentMenu(context, isMine: comment.isMine);
    if (action == null || !context.mounted) return;
    switch (action) {
      case TalkCommentMenuAction.report:
        await _reportComment(comment);
      case TalkCommentMenuAction.block:
        await _blockCommentAuthor(comment);
      case TalkCommentMenuAction.delete:
        await _deleteComment(comment);
    }
  }

  /// 댓글 보내기: 첫 댓글이면 이용 규칙 동의 > 전송. 보냈으면 true
  /// 서버가 동의 안 함으로 거절하면 규칙 시트를 다시 띄우고 한 번만 다시 시도
  Future<bool> sendComment(
    String body, {
    bool canRetryAfterRules = true,
  }) async {
    final isAgreed = await ensureTalkRulesAgreed(context, ref);
    if (!isAgreed || !context.mounted) return false;
    final l10n = context.l10n;
    try {
      await _comments.add(body);
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      final isRulesRejected =
          canRetryAfterRules &&
          ref.read(talkRulesAgreementProvider.notifier).forgetIfRejected(e);
      if (isRulesRejected) {
        return sendComment(body, canRetryAfterRules: false);
      }
      await showFailure(
        context,
        e,
        title: l10n.talkCommentSendFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.comment,
      );
      return false;
    }
  }

  Future<void> _reportPost() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final doneText = context.l10n.talkReportDone;
    final isReported = await showTalkReportSheet(
      context,
      onSubmit: _detail.report,
    );
    if (isReported) showElumToastOn(messenger, doneText);
  }

  Future<void> _reportComment(TalkComment comment) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final doneText = context.l10n.talkReportDone;
    final isReported = await showTalkReportSheet(
      context,
      onSubmit: (reason) => _comments.report(comment.id, reason),
    );
    if (isReported) showElumToastOn(messenger, doneText);
  }

  /// 글쓴이 숨기기: 확인 > 요청 > 토스트 > 상세 닫기 (피드는 요청 안에서 다시 받게 함)
  Future<void> _blockPostAuthor(TalkPostDetail post) async {
    final isConfirmed = await confirmTalkBlock(
      context,
      nickname: post.authorNickname,
    );
    if (!isConfirmed || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _detail.blockAuthor();
    } catch (e) {
      if (!context.mounted) return;
      await showFailure(
        context,
        e,
        title: l10n.talkBlockFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.block,
      );
      return;
    }
    showElumToastOn(messenger, l10n.talkBlockDone);
    if (context.mounted) context.popOrHome();
  }

  /// 댓글쓴이 숨기기: 확인 > 요청 > 토스트 (댓글 목록이 다시 받아져 그 보호자 댓글이 빠진다)
  Future<void> _blockCommentAuthor(TalkComment comment) async {
    final isConfirmed = await confirmTalkBlock(
      context,
      nickname: comment.authorNickname,
    );
    if (!isConfirmed || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _comments.blockAuthorOf(comment.id);
    } catch (e) {
      if (!context.mounted) return;
      await showFailure(
        context,
        e,
        title: l10n.talkBlockFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.block,
      );
      return;
    }
    showElumToastOn(messenger, l10n.talkBlockDone);
  }

  Future<void> _editPost(TalkPostDetail post) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final savedText = context.l10n.talkEditSaved;
    final isSaved = await showTalkEditSheet(context, post);
    if (isSaved) showElumToastOn(messenger, savedText);
  }

  /// 내 글 내리기: 확인 > 요청 > 토스트 > 상세 닫기
  Future<void> _takeDownPost() async {
    final isConfirmed = await confirmTalkTakeDown(context);
    if (!isConfirmed || !context.mounted) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _detail.delete();
    } catch (e) {
      if (!context.mounted) return;
      await showFailure(
        context,
        e,
        title: l10n.talkTakeDownFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.managePost,
      );
      return;
    }
    showElumToastOn(messenger, l10n.talkTakeDownDone);
    if (context.mounted) context.popOrHome();
  }

  Future<void> _deleteComment(TalkComment comment) async {
    final isConfirmed = await confirmTalkCommentDelete(context);
    if (!isConfirmed || !context.mounted) return;
    final l10n = context.l10n;
    try {
      await _comments.remove(comment.id);
    } catch (e) {
      if (!context.mounted) return;
      await showFailure(
        context,
        e,
        title: l10n.talkCommentDeleteFailedTitle,
        fallback: l10n.talkFailedFallback,
        fallbackCode: TalkScreenCodes.comment,
      );
    }
  }
}

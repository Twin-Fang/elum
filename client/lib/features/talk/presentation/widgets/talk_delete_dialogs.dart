import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_dialog.dart';

/// "이 글을 내릴까요?" 확인: 내리기를 누르면 true
Future<bool> confirmTalkTakeDown(BuildContext context) => _confirmDelete(
  context,
  title: context.l10n.talkTakeDownTitle,
  message: context.l10n.talkTakeDownMessage,
  actionLabel: context.l10n.talkMenuTakeDown,
);

/// "댓글을 지울까요?" 확인: 지우기를 누르면 true
Future<bool> confirmTalkCommentDelete(BuildContext context) => _confirmDelete(
  context,
  title: context.l10n.talkCommentDeleteTitle,
  actionLabel: context.l10n.talkCommentDeleteAction,
);

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String? message,
}) async {
  final isConfirmed = await showElumDialog<bool>(
    context: context,
    title: title,
    message: message,
    icon: ElumDialogIcon.trash,
    actions: [
      ElumDialogAction(
        label: context.l10n.commonCancel,
        value: false,
        tone: ElumDialogTone.neutral,
      ),
      ElumDialogAction(
        label: actionLabel,
        value: true,
        tone: ElumDialogTone.danger,
      ),
    ],
  );
  return isConfirmed ?? false;
}

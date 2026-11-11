import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_danger_confirm_dialog.dart';

/// "{닉네임}님 글을 숨길까요?" 확인: 숨기기를 누르면 true
Future<bool> confirmTalkBlock(
  BuildContext context, {
  required String? nickname,
}) async {
  final l10n = context.l10n;
  return confirmDangerousAction(
    context,
    icon: ElumDangerIcon.alert,
    title: l10n.talkBlockTitle(nickname ?? l10n.talkAuthorFallback),
    message: l10n.talkBlockMessage,
    actionLabel: l10n.talkBlockAction,
  );
}

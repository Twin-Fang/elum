import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/routine.dart';
import '../../talk/application/talk_link_actions.dart';
import '../../talk/domain/talk_screen_codes.dart';

/// 일과관리 링크 동작: 보내기(링크로 보내기 화면), 끄기(확인 > 요청 > 토스트 · 실패 팝업)

/// 링크로 보내기 화면 열기 (켜진 링크가 있으면 화면이 같은 링크를 다시 보낸다)
void openRoutineLinkShare(
  BuildContext context,
  Routine routine, {
  required bool hasActiveLink,
}) {
  final TalkLinkShareRouteArgs args = (
    routineId: routine.id,
    hasActiveLink: hasActiveLink,
  );
  context.push(Routes.guardianTalkLinkShare, extra: args);
}

/// 링크 끄기: 확인 > 글 내리기 요청 > 토스트. 실패하면 에러 코드가 붙은 팝업
Future<void> turnOffRoutineLink(
  BuildContext context,
  WidgetRef ref, {
  required String linkPostId,
}) async {
  final l10n = context.l10n;
  final isConfirmed = await showElumDialog<bool>(
    context: context,
    title: l10n.talkLinkTurnOffTitle,
    message: l10n.talkLinkTurnOffMessage,
    icon: ElumDialogIcon.alert,
    actions: [
      ElumDialogAction(
        label: l10n.commonCancel,
        value: false,
        tone: ElumDialogTone.neutral,
      ),
      ElumDialogAction(
        label: l10n.talkLinkTurnOff,
        value: true,
        tone: ElumDialogTone.danger,
      ),
    ],
  );
  if (isConfirmed != true || !context.mounted) return;
  try {
    await ref.read(talkLinkActionsProvider).turnOff(linkPostId);
  } catch (e) {
    if (!context.mounted) return;
    await showFailure(
      context,
      e,
      title: l10n.talkLinkTurnOffFailedTitle,
      fallback: l10n.talkFailedFallback,
      fallbackCode: TalkScreenCodes.routineLink,
    );
    return;
  }
  if (context.mounted) showElumToast(context, l10n.talkLinkTurnOffDone);
}

import 'package:flutter/widgets.dart';

import '../l10n/l10n_context.dart';
import 'elum_dialog.dart';

/// 비밀암호 잊음 팝업: 다시 로그인 > 로그아웃(잠금도 지움) > 로그인 뒤 암호 만들기(`PinChangeScreen.createOnly`)
/// true = 다시 로그인 고름 (닫기·바깥은 false)
Future<bool> confirmPinForgotRelogin(BuildContext context) async {
  final l10n = context.l10n;
  final isReloginChosen = await showElumDialog<bool>(
    context: context,
    title: l10n.pinForgotTitle,
    message: l10n.pinForgotMessage,
    barrierDismissible: true,
    actions: [
      ElumDialogAction(label: l10n.commonClose, value: false, tone: ElumDialogTone.neutral),
      ElumDialogAction(label: l10n.pinForgotRelogin, value: true),
    ],
  );
  return isReloginChosen ?? false;
}

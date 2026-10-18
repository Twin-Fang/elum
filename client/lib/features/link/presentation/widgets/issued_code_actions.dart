import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../profile/application/invite_sharer.dart';
import '../../domain/link_status.dart';

/// 발급된 코드를 클립보드에 복사: 만료됐거나 코드가 없으면 하지 않음
Future<void> copyIssuedCode(BuildContext context, IssuedLinkCode? issued) async {
  if (issued == null || issued.isExpired) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  try {
    await Clipboard.setData(ClipboardData(text: issued.code));
    showElumToastOn(messenger, l10n.issuedCodeCopied);
  } catch (error) {
    // 복사가 막혀도 코드는 화면에 그대로 있다 - 팝업으로 알리고 에러 코드를 붙인다.
    if (!context.mounted) return;
    await showFailure(
      context,
      error,
      title: l10n.issuedCodeCopyFailedTitle,
      fallback: l10n.issuedCodeCopyFailedFallback,
      fallbackCode: 'E-CODE-COPY',
    );
  }
}

/// `링크로 보내기` 버튼: 누르는 순간 지금 보이는 코드로 공유 시트를 연다
///
/// 코드가 없거나 만료됐으면 꺼진다 - 받은 사람이 못 쓰는 코드를 퍼뜨리지 않는다.
/// 링크 문구는 [shareMessage] 가 **누를 때** 만든다. 다시 만들면 앞 코드가 폐기되므로 화면의 코드와 남은 시간으로 보낸다.
class IssuedCodeShareButton extends ConsumerWidget {
  const IssuedCodeShareButton({
    super.key,
    required this.issued,
    required this.shareMessage,
    required this.shareFailCode,
    this.isSecondary = false,
  });

  final IssuedLinkCode? issued;

  /// 공유 시트에 실을 문구. 코드를 로그에 남기지 않도록 예외에는 코드를 싣지 않는 쪽이 만든다.
  final String Function(IssuedLinkCode issued) shareMessage;

  /// 공유 시트를 못 열었을 때 팝업에 붙는 식별자.
  final String shareFailCode;

  /// 보조 색으로 그린다. 같은 화면에 `시작하기` 같은 주 버튼이 따로 있을 때.
  final bool isSecondary;

  bool get _isUsable {
    final i = issued;
    return i != null && !i.isExpired;
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final i = issued;
    if (i == null || i.isExpired) return;
    try {
      await ref.read(inviteSharerProvider)(shareMessage(i));
    } catch (e) {
      if (!context.mounted) return;
      await showFailure(
        context,
        e,
        title: context.l10n.inviteCodeShareFailTitle,
        fallback: context.l10n.inviteCodeShareFailFallback,
        fallbackCode: shareFailCode,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isUsable = _isUsable;
    return ElumButton(
      label: context.l10n.inviteCodeShareButton,
      onPressed: isUsable ? () => _share(context, ref) : null,
      // 켜졌을 때만 보조 색이다 - 꺼진 버튼은 공용 비활성 색을 그대로 쓴다.
      backgroundColor: isSecondary && isUsable ? colors.linkRetryChipBg : null,
      labelColor: isSecondary && isUsable ? colors.textPrimary : null,
    );
  }
}

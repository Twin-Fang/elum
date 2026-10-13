import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../profile/application/invite_sharer.dart';
import '../../domain/link_status.dart';

/// 발급된 코드를 다른 휴대폰에 전하는 하단 버튼 둘 — 주 `링크로 보내기`, 보조 `코드 복사하기`.
///
/// 초대 코드 화면과 연결 암호 화면이 같은 부품을 쓴다. 코드가 없거나 만료됐으면 둘 다 꺼진다 —
/// 받은 사람이 못 쓰는 코드를 퍼뜨리지 않는다.
///
/// 링크 문구는 [shareMessage] 가 **누를 때** 만든다. 다시 만들면 앞 코드가 폐기되므로 지금 화면에 보이는
/// 코드와 남은 시간으로 보내야 한다.
class IssuedCodeActions extends ConsumerWidget {
  const IssuedCodeActions({
    super.key,
    required this.issued,
    required this.shareMessage,
    required this.shareFailCode,
  });

  final IssuedLinkCode? issued;

  /// 공유 시트에 실을 문구. 코드를 로그에 남기지 않도록 예외에는 코드를 싣지 않는 쪽이 만든다.
  final String Function(IssuedLinkCode issued) shareMessage;

  /// 공유 시트를 못 열었을 때 팝업에 붙는 식별자.
  final String shareFailCode;

  /// 두 버튼 사이 간격.
  static const _gap = 12.0;

  bool get _usable {
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

  Future<void> _copy(BuildContext context) async {
    final i = issued;
    if (i == null || i.isExpired) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      await Clipboard.setData(ClipboardData(text: i.code));
      showElumToastOn(messenger, l10n.issuedCodeCopied);
    } catch (_) {
      // 복사가 막혀도 코드는 화면에 그대로 있다 — 알리기만 한다.
      showElumToastOn(messenger, l10n.issuedCodeCopyFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final usable = _usable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElumButton(
          label: context.l10n.inviteCodeShareButton,
          onPressed: usable ? () => _share(context, ref) : null,
        ),
        SizedBox(height: _gap.h),
        ElumButton(
          label: context.l10n.issuedCodeCopyButton,
          onPressed: usable ? () => _copy(context) : null,
          // 켜졌을 때만 보조 색이다 — 꺼진 버튼은 공용 비활성 색을 그대로 쓴다.
          backgroundColor: usable ? colors.linkRetryChipBg : null,
          labelColor: usable ? colors.textPrimary : null,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/elum_floating_pill_button.dart';

/// 이야기 칸 아래 가운데 떠 있는 `+ 올리기` (시안 1783:6836)
class TalkWriteButton extends StatelessWidget {
  const TalkWriteButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  /// 목록 끝이 버튼 아래로 숨지 않게 남길 아래 여백
  static const scrollBottomSpace = ElumFloatingPillButton.scrollBottomSpace;

  @override
  Widget build(BuildContext context) {
    return ElumFloatingPillButton(
      label: context.l10n.talkWriteButton,
      onTap: onPressed,
    );
  }
}

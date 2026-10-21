import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_multiline_text_field.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../domain/talk_text_limits.dart';

/// 댓글 입력줄: 여러 줄 입력창 + 보내기. 보내기에 실패하면(false) 적은 글을 그대로 둔다
class TalkCommentInput extends StatefulWidget {
  const TalkCommentInput({super.key, required this.onSubmit});

  /// 보냈으면 true (입력창을 비운다), 실패·취소면 false
  final Future<bool> Function(String body) onSubmit;

  @override
  State<TalkCommentInput> createState() => _TalkCommentInputState();
}

class _TalkCommentInputState extends State<TalkCommentInput> {
  final _controller = TextEditingController();
  bool _isSending = false;

  /// 공백만 있는 글은 보내지 않는다
  bool get _canSend => !_isSending && _controller.text.trim().isNotEmpty;

  /// 입력줄이 늘어날 수 있는 최대 줄 수
  static const _maxVisibleLines = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _isSending = true);
    final isSent = await widget.onSubmit(_controller.text.trim());
    if (!mounted) return;
    setState(() => _isSending = false);
    if (isSent) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.screenH.w,
        space.xs.h,
        space.screenH.w,
        space.xs.h,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ElumMultilineTextField(
              controller: _controller,
              hintText: context.l10n.talkCommentHint,
              maxLength: TalkTextLimits.maxCommentLength,
              minLines: 1,
              maxLines: _maxVisibleLines,
              enabled: !_isSending,
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(width: space.xs.w),
          _SendButton(
            isSending: _isSending,
            onPressed: _canSend ? _send : null,
          ),
        ],
      ),
    );
  }
}

/// 보내기 버튼: 글이 있어야 켜진다
class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onPressed});

  final bool isSending;
  final VoidCallback? onPressed;

  static const _paddingH = 16.0;
  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEnabled = onPressed != null;
    return AppPressable(
      onTap: onPressed,
      child: Container(
        height: _height.h,
        padding: EdgeInsets.symmetric(horizontal: _paddingH.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isEnabled ? colors.buttonEnabled : colors.buttonDisabled,
          borderRadius: BorderRadius.circular(context.space.buttonRadius.r),
        ),
        child: isSending
            ? ElumSpinner(size: 20.w, color: colors.buttonDisabledText)
            : Text(
                context.l10n.talkCommentSend,
                style: context.typo.chipLabel.copyWith(
                  color: isEnabled
                      ? colors.buttonEnabledText
                      : colors.buttonDisabledText,
                ),
              ),
      ),
    );
  }
}
